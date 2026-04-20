// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinLoginScreen extends StatefulWidget {
  final String generatedPin;

  const PinLoginScreen({super.key, required this.generatedPin});

  @override
  _PinLoginScreenState createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with SingleTickerProviderStateMixin {
  String currentPin = "";
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool isLoading = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _initializeNotification();

    // Debug: Print PIN untuk development (hapus di production)
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (currentPin.length < 6) {
      setState(() => currentPin += digit);
      if (currentPin.length == 6) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (currentPin == widget.generatedPin) {
            _confirmPin(currentPin, context);
          } else {
            setState(() => currentPin = "");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("PIN tidak valid!"),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  void _deleteDigit() {
    if (currentPin.isNotEmpty) {
      setState(
        () => currentPin = currentPin.substring(0, currentPin.length - 1),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> receiptData) {
    _controller.forward();
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth * 0.5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: screenWidth * 0.08,
                horizontal: screenWidth * 0.06,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/berhasil.gif',
                    width: imageSize,
                    height: imageSize,
                  ),
                  SizedBox(height: screenWidth * 0.05),
                  Text(
                    'Pin Login Berhasil!',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.025),
                  const Text(
                    'Pin Login Berhasil diaktifkan!',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenWidth * 0.08),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Delay sebelum kembali ke halaman sebelumnya
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Tutup dialog
      Navigator.of(
        context,
      ).pop(true); // Kembali ke halaman sebelumnya, kirim hasil
    });
  }

  void _initializeNotification() async {
    await _requestNotificationPermission();
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: null,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
    await _createNotificationChannel();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
          // Permission granted
        } else if (status.isDenied) {
          if (mounted) {
            _showPermissionDialog();
          }
        } else if (status.isPermanentlyDenied) {
          if (mounted) {
            _showSettingsDialog();
          }
        }

        final notificationPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (notificationPlugin != null) {
          // Additional Android-specific setup if needed
        }
      }

      if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          if (granted != true) {
            if (mounted) {
              _showPermissionDialog();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan saat memproses izin notifikasi.'),
          ),
        );
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'Pin Login Channel',
        'Pin Login Sukses',
        description: 'Notifikasi untuk Pin Login berhasil',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Notifikasi'),
          content: const Text(
            'Aplikasi membutuhkan izin notifikasi untuk memberitahu Anda ketika transaksi berhasil. '
            'Silakan berikan izin notifikasi agar Anda tidak melewatkan informasi penting.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestNotificationPermission();
              },
              child: const Text('Berikan Izin'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Notifikasi Diperlukan'),
          content: const Text(
            'Izin notifikasi telah ditolak secara permanen. '
            'Silakan buka pengaturan aplikasi untuk mengaktifkan notifikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessNotification() async {
    try {
      bool hasPermission = false;
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        hasPermission = status.isGranted;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        hasPermission = true;
      }

      if (!hasPermission) {
        return;
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'Pin_Login_Channel',
            'Pin Login Sukses',
            channelDescription: 'Notifikasi untuk Pin Login berhasil',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap(
              '@mipmap/ic_launcher',
            ),
            styleInformation: BigTextStyleInformation(
              'Pin Login Berhasil Diaktifkan',
              contentTitle: 'Pin Login Berhasil',
              summaryText: 'Selamat! Pin Login Anda telah berhasil diaktifkan.',
            ),
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        subtitle: 'Pin Login Berhasil',
        threadIdentifier: 'Pin_Login_success',
      );

      final NotificationDetails notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        'Pin Login Berhasil',
        'Pin Login Anda telah berhasil diaktifkan.',
        notifDetails,
        payload: 'Pin_Login_success_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menampilkan notifikasi keberhasilan.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Konfirmasi PIN Login",
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final isSmallScreen = screenWidth < 360;
            final isTablet = screenWidth > 600;
            final isLandscape = screenWidth > screenHeight;

            // Responsive calculations
            final pinBoxSize = isTablet
                ? screenWidth * 0.08
                : isSmallScreen
                ? screenWidth * 0.13
                : screenWidth * 0.12;

            final buttonSize = isTablet
                ? (isLandscape ? 65.0 : 80.0)
                : isSmallScreen
                ? 45.0
                : (isLandscape ? 50.0 : 60.0);

            final spacing = isTablet
                ? 16.0
                : isSmallScreen
                ? 6.0
                : (isLandscape ? 8.0 : 10.0);

            final horizontalPadding = isTablet
                ? 32.0
                : isSmallScreen
                ? 16.0
                : 24.0;

            final titleFontSize = isTablet
                ? 18.0
                : isSmallScreen
                ? 13.0
                : 16.0;

            final buttonFontSize = isTablet
                ? 18.0
                : isSmallScreen
                ? 14.0
                : 16.0;

            return Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top section with PIN input
                          Column(
                            children: [
                              SizedBox(height: isLandscape ? 10 : 20),
                              Text(
                                "Silakan masukkan 6 Pin Login Anda untuk melindungi akun Anda.",
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  color: Colors.grey,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isLandscape ? 15 : 25),

                              // PIN boxes with responsive spacing
                              SizedBox(
                                width: double.infinity,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    6,
                                    (index) => _buildResponsivePinBox(
                                      index,
                                      pinBoxSize,
                                      isSmallScreen,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: isLandscape ? 15 : 25),

                              // Confirm button
                              SizedBox(
                                width: double.infinity,
                                height: isTablet
                                    ? 60
                                    : (isSmallScreen ? 45 : 50),
                                child: ElevatedButton(
                                  onPressed:
                                      currentPin.length == 6 && !isLoading
                                      ? () => _confirmPin(currentPin, context)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    backgroundColor: Colors.blue,
                                    disabledBackgroundColor: Colors.grey[300],
                                  ),
                                  child: isLoading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: isSmallScreen ? 16 : 20,
                                              height: isSmallScreen ? 16 : 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              "Memproses...",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: buttonFontSize,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          "Konfirmasi PIN Login",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: buttonFontSize,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),

                          // Spacer that adjusts based on available space
                          SizedBox(
                            height: isLandscape
                                ? 20
                                : isSmallScreen
                                ? 30
                                : 40,
                          ),

                          // Bottom section with keypad
                          SizedBox(
                            width: double.infinity,
                            child: _buildResponsiveKeypad(
                              buttonSize,
                              spacing,
                              isSmallScreen,
                              isTablet,
                            ),
                          ),

                          // Bottom padding for safe area
                          SizedBox(height: isSmallScreen ? 10 : 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // Loading overlay
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(20),
                        margin: EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 15),
                            Text(
                              'Memproses PIN Login...',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsivePinBox(
    int index,
    double pinBoxSize,
    bool isSmallScreen,
  ) {
    String? char = index < currentPin.length ? currentPin[index] : null;
    return Container(
      width: pinBoxSize,
      height: pinBoxSize * 1.1,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: char != null ? Colors.blue : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Text(
        char != null ? (index == currentPin.length - 1 ? char : "•") : "",
        style: TextStyle(
          fontSize: pinBoxSize * (isSmallScreen ? 0.5 : 0.6),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildResponsiveKeypad(
    double buttonSize,
    double spacing,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Container(
      constraints: BoxConstraints(maxWidth: isTablet ? 400 : double.infinity),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.0,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ...List.generate(
            9,
            (i) => _buildResponsiveNumberButton(
              "${i + 1}",
              buttonSize,
              isSmallScreen,
            ),
          ),
          _buildResponsiveNumberButton("*", buttonSize, isSmallScreen),
          _buildResponsiveNumberButton("0", buttonSize, isSmallScreen),
          _buildResponsiveDeleteButton(buttonSize, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildResponsiveNumberButton(
    String digit,
    double size,
    bool isSmallScreen,
  ) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(size * 0.25),
      child: InkWell(
        onTap: isLoading ? null : () => _addDigit(digit),
        borderRadius: BorderRadius.circular(size * 0.25),
        splashColor: Colors.blue.withOpacity(0.2),
        highlightColor: Colors.blue.withOpacity(0.1),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: isLoading ? Colors.grey[300] : Colors.grey[100],
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: size * (isSmallScreen ? 0.32 : 0.35),
                fontWeight: FontWeight.bold,
                color: isLoading ? Colors.grey[500] : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveDeleteButton(double size, bool isSmallScreen) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(size * 0.25),
      child: InkWell(
        onTap: isLoading ? null : _deleteDigit,
        borderRadius: BorderRadius.circular(size * 0.25),
        splashColor: Colors.red.withOpacity(0.2),
        highlightColor: Colors.red.withOpacity(0.1),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: isLoading ? Colors.grey[300] : Colors.red[50],
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: Colors.red[200]!, width: 1),
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: size * (isSmallScreen ? 0.32 : 0.35),
              color: isLoading ? Colors.grey[500] : Colors.red[600],
            ),
          ),
        ),
      ),
    );
  }

  // Main function: Confirm PIN and call PIN payment API
  void _confirmPin(String pin, BuildContext context) async {
    // Validasi PIN dengan yang diterima dari generate
    if (pin == widget.generatedPin) {
      setState(() {
        isLoading = true;
      });

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
            // Prepare request payload sesuai dengan API PIN
            final pinLoginData = {"pin": pin};

            // Call PIN payment API
            final response = await http.post(
              Uri.parse('$baseURL/api/gv/gardira/pin/payment'),
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(pinLoginData),
            );

            setState(() {
              isLoading = false;
            });

            if (response.statusCode == 200) {
              final responseData = json.decode(response.body);

              // Check if payment was successful
              if (responseData['responseCode'] == "2007400" ||
                  responseData['responseMessage']
                      .toString()
                      .toLowerCase()
                      .contains('success')) {
                Map<String, dynamic> pinData = {
                  // Data tambahan dari response API
                  if (responseData['data'] != null) ...responseData['data'],
                };
                final prefs = await SharedPreferences.getInstance();
                setState(() {
                  _userEmail = prefs.getString('Email');
                });

                if (mounted) {
                  setState(() => currentPin = ""); // Reset PIN
                  _showSuccessDialog(pinData);
                  await _addNotificationToDatabase(_userEmail ?? '', pinData);
                  _showSuccessNotification();
                }
              } else {
                // Show error message from API
                if (mounted) {
                  setState(() => currentPin = ""); // Reset PIN
                  _showErrorDialog(
                    context,
                    responseData['responseMessage'] ??
                        'Terjadi kesalahan saat proses pembayaran.',
                  );
                }
              }
            } else if (response.statusCode == 400) {
              if (mounted) {
                setState(() => currentPin = ""); // Reset PIN
                _showErrorDialog(
                  context,
                  'PIN tidak valid atau sudah kadaluarsa.',
                );
              }
            } else if (response.statusCode == 403) {
              if (mounted) {
                setState(() => currentPin = ""); // Reset PIN
                _showErrorDialog(
                  context,
                  'Saldo anda tidak mencukupi untuk melakukan transaksi ini.',
                );
              }
            } else if (response.statusCode == 500) {
              if (mounted) {
                setState(() => currentPin = ""); // Reset PIN
                _showErrorDialog(
                  context,
                  'Terjadi kesalahan pada server. Silakan coba lagi.',
                );
              }
            } else {
              if (mounted) {
                setState(() => currentPin = ""); // Reset PIN
                _showErrorDialog(
                  context,
                  'Gagal melakukan pembayaran. Kode: ${response.statusCode}',
                );
              }
            }
          } else {
            setState(() {
              isLoading = false;
              currentPin = ""; // Reset PIN
            });
            if (mounted) {
              _showErrorDialog(context, 'Gagal mendapatkan token otorisasi.');
            }
          }
        } else {
          setState(() {
            isLoading = false;
            currentPin = ""; // Reset PIN
          });
          if (mounted) {
            _showErrorDialog(
              context,
              'Gagal mendapatkan token. Kode: ${tokenResponse.statusCode}',
            );
          }
        }
      } catch (e) {
        setState(() {
          isLoading = false;
          currentPin = ""; // Reset PIN
        });
        if (mounted) {
          _showErrorDialog(
            context,
            'Terjadi kesalahan saat melakukan pembayaran. Silakan coba lagi.',
          );
        }
      }
    } else {
      // PIN doesn't match
      setState(() => currentPin = ""); // Reset PIN
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PIN tidak valid! Silakan coba lagi."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update bagian _addNotificationToDatabase di PinLoginScreen
  Future<void> _addNotificationToDatabase(
    String userEmail,
    Map<String, dynamic> receiptData,
  ) async {
    try {
      // Get access token
      final tokenResponse = await http.post(
        Uri.parse('$baseURL/Token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'password': '1bBsNgVCMDm6oR3y+GLN090i8japjlxzIhSUGPO1REE=',
        },
      );

      if (tokenResponse.statusCode == 200) {
        final tokenData = json.decode(tokenResponse.body);
        final accessToken = tokenData['access_token'];

        if (accessToken != null) {
          // Prepare notification data dengan Type
          final notificationData = {
            "Title": "PIN Login Berhasil!",
            "Message":
                "Perubahan PIN Login berhasil dilakukan. PIN baru Anda adalah ${receiptData['pin']}.",
            "Email": userEmail,
            "Type": "PIN Login",
          };

          // Call add notification API
          final response = await http.post(
            Uri.parse('$baseURL/api/Va/add/notifikasi'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(notificationData),
          );

          if (response.statusCode == 200) {
            // Notifikasi berhasil ditambahkan
          } else {
            // Gagal menambahkan notifikasi
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan notifikasi ke database.'),
          ),
        );
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 15),
              Text(
                'Transaksi Gagal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF015479),
                  minimumSize: const Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                },
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
