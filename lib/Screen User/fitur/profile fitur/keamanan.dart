// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/keamanan/setuppin.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/ubahkatasandi.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HalamanPengaturanKeamanan extends StatefulWidget {
  const HalamanPengaturanKeamanan({super.key});

  @override
  _HalamanPengaturanKeamananState createState() =>
      _HalamanPengaturanKeamananState();
}

class _HalamanPengaturanKeamananState extends State<HalamanPengaturanKeamanan> {
  bool tokenLogin = true;
  bool _isLoading = false;
  bool pinLogin = false;
  bool _isLoadingInitial = true;
  bool _isPinLoading = false;
  bool _hasPinSetup = false;
  String? _userEmail;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('Email');
      _userId = prefs.getString('UserID');
    });

    // Load OTP setting
    bool? savedOtpSetting = prefs.getBool('RequireOtp');
    if (savedOtpSetting != null) {
      setState(() {
        tokenLogin = savedOtpSetting;
      });
      await _loadOtpSettingFromServer();
    } else {
      await _loadOtpSettingFromServer();
    }

    // Load PIN setting
    await _loadPinSettingFromServer();
  }

  Future<void> _loadOtpSettingFromServer() async {
    if (_userEmail == null) {
      setState(() {
        _isLoadingInitial = false;
      });
      return;
    }

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
          final response = await http.post(
            Uri.parse('$baseURL/api/asn/getUserSettings'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'identifier': _userEmail}),
          );

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            bool currentOtpSetting = responseData['requireOtp'] ?? true;

            setState(() {
              tokenLogin = currentOtpSetting;
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('RequireOtp', currentOtpSetting);
          }
        }
      }
    } catch (e) {
      _showSnackBar('Gagal memuat pengaturan OTP', Colors.red);
    } finally {
      setState(() {
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _loadPinSettingFromServer() async {
    if (_userId == null) {
      return;
    }

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
          final response = await http.post(
            Uri.parse('$baseURL/api/pin/status'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'UserId': _userId}),
          );

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);

            if (responseData['Success'] == true) {
              final data = responseData['Data'];
              bool pinEnabled = data['Enabled'] ?? false;
              bool hasPin = data['HasPin'] ?? false;

              setState(() {
                pinLogin = pinEnabled;
                _hasPinSetup = hasPin;
              });

              // Save to SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('PinEnabled', pinEnabled);
              await prefs.setBool('HasPin', hasPin);
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat pengaturan PIN. Silakan coba lagi.'),
        ),
      );
    }
  }

  Future<void> _updateOtpSetting(bool requireOtp, [String? password]) async {
    if (_userEmail == null) {
      _showSnackBar('Email pengguna tidak ditemukan', Colors.red);
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
      if (tokenResponse.statusCode != 200) {
        throw Exception('Gagal mendapatkan token akses');
      }

      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'];

      if (accessToken == null) {
        throw Exception('Token tidak valid');
      }

      Map<String, dynamic> requestBody = {
        'Email': _userEmail,
        'RequireOtp': requireOtp,
      };

      if (!requireOtp) {
        if (password == null || password.isEmpty) {
          throw Exception('Password wajib diisi untuk menonaktifkan OTP');
        }
        requestBody['Password'] = password;
      }

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/UpdateOtpSetting'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          tokenLogin = requireOtp;
        });
        _showSnackBar(
          responseData['message'] ?? 'Pengaturan berhasil diubah',
          Colors.green,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('RequireOtp', requireOtp);
      } else if (response.statusCode == 401) {
        final errorData = json.decode(response.body);

        throw Exception(
          errorData['Message'] ?? 'Akses ditolak. Periksa password Anda.',
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['Message'] ?? 'Gagal mengubah pengaturan');
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', Colors.red);
      setState(() {
        tokenLogin = !requireOtp;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePinSetting(bool enabled) async {
    if (_userId == null) {
      _showSnackBar('User ID tidak ditemukan', Colors.red);
      return;
    }

    setState(() {
      _isPinLoading = true;
    });

    try {
      // Ambil token
      final tokenResponse = await http.post(
        Uri.parse('$baseURL/api/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'grant_type': 'password', 'password': 'ASN_DBS'},
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception(
          'Gagal mendapatkan token akses. Status: ${tokenResponse.statusCode}',
        );
      }

      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'];
      if (accessToken == null) {
        throw Exception('Token tidak valid dari server.');
      }

      // Kirim request toggle PIN
      final response = await http.post(
        Uri.parse('$baseURL/api/pin/toggle'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'UserId': _userId, 'Enabled': enabled}),
      );

      // Coba decode JSON, fallback ke string biasa jika gagal
      String message = '';
      bool success = false;

      try {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          success =
              responseData['success'] == true ||
              responseData['Success'] == true;
          message = responseData['message'] ?? responseData['Message'] ?? '';
        }
      } catch (_) {
        // Jika body bukan JSON valid, gunakan langsung sebagai message
        message = response.body.toString();
      }

      if (response.statusCode == 200 && success) {
        setState(() {
          pinLogin = enabled;
        });
        _showSnackBar(
          message.isNotEmpty ? message : 'PIN berhasil diperbarui',
          Colors.green,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('PinEnabled', enabled);
      } else {
        throw Exception(
          message.isNotEmpty ? message : 'Gagal mengubah pengaturan PIN',
        );
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', Colors.red);

      // Revert switch UI agar tidak membingungkan pengguna
      setState(() {
        pinLogin = !enabled;
      });
    } finally {
      setState(() {
        _isPinLoading = false;
      });
    }
  }

  void _handlePinToggle(bool value) {
    if (value && !_hasPinSetup) {
      // Jika user ingin mengaktifkan PIN tapi belum setup, arahkan ke setup
      _navigateToPinSetup();
    } else if (value && _hasPinSetup) {
      // Jika user sudah punya PIN, langsung aktifkan
      _updatePinSetting(true);
    } else {
      // Nonaktifkan PIN
      _showPinDisableConfirmation();
    }
  }

  void _navigateToPinSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PinSetupScreen(userId: _userId!)),
    ).then((result) {
      if (result == true) {
        // PIN berhasil disetup
        setState(() {
          _hasPinSetup = true;
          pinLogin = true;
        });
        _loadPinSettingFromServer(); // Refresh status
      }
    });
  }

  void _showPinDisableConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nonaktifkan PIN'),
          content: const Text(
            'Apakah Anda yakin ingin menonaktifkan PIN? '
            'Ini akan mengurangi tingkat keamanan aplikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  pinLogin = true; // Kembalikan ke posisi semula
                });
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updatePinSetting(false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Nonaktifkan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isVerySmallScreen = screenHeight < 600;
    final padding = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Keamanan',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(padding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Token Login Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: isVerySmallScreen ? 2.0 : 4.0,
                                horizontal: 4.0,
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 8.0 : 12.0,
                                  vertical: isVerySmallScreen ? 2.0 : 4.0,
                                ),
                                title: Text(
                                  'Token Login (OTP)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: isSmallScreen ? 13 : 14,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    tokenLogin
                                        ? 'Aktif - Memerlukan kode OTP saat login'
                                        : 'Nonaktif - Login tanpa kode OTP',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isSmallScreen ? 11 : 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                value: tokenLogin,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        if (!value) {
                                          _showPasswordConfirmationDialog(
                                            value,
                                          );
                                        } else {
                                          _showConfirmationDialog(value);
                                        }
                                      },
                                activeColor: Colors.blue,
                                secondary: _isLoading
                                    ? SizedBox(
                                        width: isSmallScreen ? 18 : 20,
                                        height: isSmallScreen ? 18 : 20,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        tokenLogin
                                            ? Icons.security
                                            : Icons.security_outlined,
                                        color: tokenLogin
                                            ? Colors.blue
                                            : Colors.grey,
                                        size: isSmallScreen ? 18 : 20,
                                      ),
                              ),
                            ),
                          ),

                          SizedBox(height: isVerySmallScreen ? 8 : 12),

                          // PIN Login Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: isVerySmallScreen ? 2.0 : 4.0,
                                horizontal: 4.0,
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 8.0 : 12.0,
                                  vertical: isVerySmallScreen ? 2.0 : 4.0,
                                ),
                                title: Text(
                                  'PIN Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: isSmallScreen ? 13 : 14,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    pinLogin
                                        ? 'Aktif - Memerlukan PIN saat login'
                                        : _hasPinSetup
                                        ? 'Nonaktif - Login tanpa PIN'
                                        : 'Belum diatur - Tap untuk setup PIN',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isSmallScreen ? 11 : 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                value: pinLogin,
                                onChanged: _isPinLoading
                                    ? null
                                    : _handlePinToggle,
                                activeColor: Colors.blue,
                                secondary: _isPinLoading
                                    ? SizedBox(
                                        width: isSmallScreen ? 18 : 20,
                                        height: isSmallScreen ? 18 : 20,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        pinLogin
                                            ? Icons.dialpad
                                            : _hasPinSetup
                                            ? Icons.lock_outline
                                            : Icons.lock_open_outlined,
                                        color: pinLogin
                                            ? Colors.blue
                                            : Colors.grey,
                                        size: isSmallScreen ? 18 : 20,
                                      ),
                              ),
                            ),
                          ),

                          SizedBox(height: isVerySmallScreen ? 16 : 20),

                          // Action Buttons
                          buildActionButton(
                            'Ubah Kata Sandi',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ChangePasswordScreen(),
                                ),
                              );
                            },
                            isSmallScreen,
                            isVerySmallScreen,
                          ),

                          // Button "Ubah PIN" hanya muncul jika PIN login aktif DAN sudah ada PIN setup
                          if (pinLogin && _hasPinSetup) ...[
                            SizedBox(height: isVerySmallScreen ? 8 : 12),
                            buildActionButton(
                              'Ubah PIN',
                              () {
                                _navigateToPinSetup();
                              },
                              isSmallScreen,
                              isVerySmallScreen,
                            ),
                          ],

                          // Bottom spacing
                          SizedBox(height: isVerySmallScreen ? 20 : 40),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showPasswordConfirmationDialog(bool newValue) {
    final TextEditingController passwordController = TextEditingController();
    bool isPasswordVisible = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isVerySmallScreen = screenHeight < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 16,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12.0 : 16.0,
                vertical: isVerySmallScreen ? 12.0 : 20.0,
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: screenHeight * 0.8,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: isSmallScreen
                            ? 32
                            : isVerySmallScreen
                            ? 36
                            : 40,
                        color: const Color(0xFF246AFD),
                      ),
                      SizedBox(height: isVerySmallScreen ? 8 : 12),
                      Text(
                        'Konfirmasi Password',
                        style: TextStyle(
                          fontSize: isSmallScreen
                              ? 16
                              : isVerySmallScreen
                              ? 17
                              : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isVerySmallScreen ? 6 : 8),
                      Text(
                        'Untuk menonaktifkan Token Login (OTP), masukkan password Anda sebagai verifikasi:',
                        style: TextStyle(
                          fontSize: isSmallScreen
                              ? 12
                              : isVerySmallScreen
                              ? 13
                              : 14,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isVerySmallScreen ? 12 : 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                          ),
                          prefixIcon: Icon(
                            Icons.lock,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF246AFD),
                              size: isSmallScreen ? 16 : 18,
                            ),
                            onPressed: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.1),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 10 : 12,
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                        ),
                        style: TextStyle(fontSize: isSmallScreen ? 12 : 13),
                      ),
                      SizedBox(height: isVerySmallScreen ? 12 : 16),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF246AFD).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF246AFD).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: const Color(0xFF246AFD),
                              size: isSmallScreen ? 14 : 16,
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Expanded(
                              child: Text(
                                'Menonaktifkan OTP akan mengurangi keamanan akun Anda.',
                                style: TextStyle(
                                  color: const Color(0xFF246AFD),
                                  fontSize: isSmallScreen ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isVerySmallScreen ? 16 : 20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: isVerySmallScreen ? 36 : 40,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 12,
                                    vertical: isSmallScreen ? 6 : 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  foregroundColor: Colors.grey[700],
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Batal',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Expanded(
                            child: SizedBox(
                              height: isVerySmallScreen ? 36 : 40,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF246AFD),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 12,
                                    vertical: isSmallScreen ? 6 : 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: () {
                                  if (passwordController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password harus diisi'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.of(context).pop();
                                  _updateOtpSetting(
                                    newValue,
                                    passwordController.text.trim(),
                                  );
                                },
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Nonaktifkan OTP',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmationDialog(bool newValue) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isVerySmallScreen = screenHeight < 600;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 16,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12.0 : 16.0,
            vertical: isVerySmallScreen ? 12.0 : 20.0,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: screenHeight * 0.7,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security,
                    size: isSmallScreen
                        ? 32
                        : isVerySmallScreen
                        ? 36
                        : 40,
                    color: const Color(0xFF246AFD),
                  ),
                  SizedBox(height: isVerySmallScreen ? 8 : 12),
                  Text(
                    'Aktifkan Token Login?',
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? 16
                          : isVerySmallScreen
                          ? 17
                          : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 6 : 8),
                  Text(
                    'Dengan mengaktifkan Token Login, Anda akan menerima kode OTP via email setiap kali login untuk keamanan tambahan.',
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? 12
                          : isVerySmallScreen
                          ? 13
                          : 14,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 16 : 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: isVerySmallScreen ? 36 : 40,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 8 : 12,
                                vertical: isSmallScreen ? 6 : 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              foregroundColor: Colors.grey[700],
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Expanded(
                        child: SizedBox(
                          height: isVerySmallScreen ? 36 : 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF246AFD),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 8 : 12,
                                vertical: isSmallScreen ? 6 : 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _updateOtpSetting(newValue);
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Aktifkan',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildActionButton(
    String text,
    VoidCallback onPressed,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return SizedBox(
      width: double.infinity,
      height: isVerySmallScreen
          ? 40
          : isSmallScreen
          ? 44
          : 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF246AFD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
          ),
          elevation: 2,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen
                  ? 13
                  : isVerySmallScreen
                  ? 14
                  : 15,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
