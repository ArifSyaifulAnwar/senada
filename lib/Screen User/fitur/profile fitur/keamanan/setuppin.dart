// ignore_for_file: deprecated_member_use

import 'package:absensikaryawan/Services/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PinSetupScreen extends StatefulWidget {
  final String userId;

  const PinSetupScreen({super.key, required this.userId});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  final List<TextEditingController> _confirmControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _confirmFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isConfirmStep = false;

  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _confirmControllers) {
      controller.dispose();
    }
    for (var node in _confirmFocusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Enhanced responsive breakpoints
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
          : 20.0,

      'iconContainerTop': isVerySmallHeight
          ? 10.0
          : isSmallHeight
          ? 20.0
          : 40.0,
      'iconContainerBottom': isVerySmallHeight
          ? 12.0
          : isSmallHeight
          ? 16.0
          : 24.0,
      'titleBottom': isVerySmallHeight ? 4.0 : 8.0,
      'subtitleBottom': isVerySmallHeight
          ? 16.0
          : isSmallHeight
          ? 24.0
          : 32.0,
      'pinFieldsBottom': isVerySmallHeight
          ? 16.0
          : isSmallHeight
          ? 20.0
          : 28.0,
      'buttonBottom': isVerySmallHeight
          ? 8.0
          : isSmallHeight
          ? 12.0
          : 16.0,
      'bottomSpacing': isVerySmallHeight
          ? 10.0
          : isSmallHeight
          ? 20.0
          : 40.0,

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

  void _onPinChanged(String value, int index, bool isConfirm) {
    final focusNodes = isConfirm ? _confirmFocusNodes : _focusNodes;

    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    // Check if all fields are filled
    if (index == 5 && value.isNotEmpty) {
      if (!isConfirm) {
        _proceedToConfirm();
      } else {
        _setupPin();
      }
    }
  }

  String _getPin(bool isConfirm) {
    final controllers = isConfirm ? _confirmControllers : _controllers;
    return controllers.map((controller) => controller.text).join();
  }

  void _clearPin(bool isConfirm) {
    final controllers = isConfirm ? _confirmControllers : _controllers;
    final focusNodes = isConfirm ? _confirmFocusNodes : _focusNodes;

    for (var controller in controllers) {
      controller.clear();
    }
    focusNodes[0].requestFocus();
  }

  void _proceedToConfirm() {
    final pin = _getPin(false);
    if (pin.length != 6) {
      _showErrorMessage('PIN harus 6 digit');
      return;
    }

    setState(() {
      _isConfirmStep = true;
    });

    _slideController.forward();

    // Focus to first confirm field
    Future.delayed(const Duration(milliseconds: 300), () {
      _confirmFocusNodes[0].requestFocus();
    });
  }

  void _goBackToSetup() {
    setState(() {
      _isConfirmStep = false;
    });

    _slideController.reverse();
    _clearPin(true);

    // Focus back to first setup field
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNodes[0].requestFocus();
    });
  }

  Future<void> _setupPin() async {
    final pin = _getPin(false);
    final confirmPin = _getPin(true);

    if (pin.length != 6 || confirmPin.length != 6) {
      _showErrorMessage('PIN harus 6 digit');
      return;
    }

    if (pin != confirmPin) {
      _showErrorMessage('PIN tidak cocok. Silakan coba lagi.');
      _goBackToSetup();
      return;
    }

    setState(() {
      _isLoading = true;
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
          // Setup PIN
          final setupResponse = await http.post(
            Uri.parse('$baseURL/api/pin/setup'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'UserId': widget.userId, 'Pin': pin}),
          );

          final setupData = json.decode(setupResponse.body);

          if (setupResponse.statusCode == 200 && setupData['Success'] == true) {
            _showSuccessDialog();
          } else {
            _showErrorMessage(setupData['Message'] ?? 'Gagal menyimpan PIN');
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Flexible(child: Text('PIN Berhasil Disimpan')),
            ],
          ),
          content: const Text(
            'PIN Anda telah berhasil disimpan dan diaktifkan. '
            'Sekarang Anda dapat menggunakan PIN untuk login.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(
                  context,
                ).pop(true); // Return to security screen with success
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF246AFD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPinFields(bool isConfirm, Map<String, dynamic> responsive) {
    final controllers = isConfirm ? _confirmControllers : _controllers;
    final focusNodes = isConfirm ? _confirmFocusNodes : _focusNodes;
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
                      color: focusNodes[index].hasFocus
                          ? const Color(0xFF246AFD)
                          : Colors.grey.withOpacity(0.3),
                      width: focusNodes[index].hasFocus ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: controllers[index].text.isNotEmpty
                        ? const Color(0xFF246AFD).withOpacity(0.1)
                        : Colors.white,
                  ),
                  child: TextField(
                    controller: controllers[index],
                    focusNode: focusNodes[index],
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
                    onChanged: (value) =>
                        _onPinChanged(value, index, isConfirm),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent({
    required bool isConfirm,
    required Map<String, dynamic> responsive,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback? onButtonPressed,
    required IconData iconData,
    required Color iconColor,
  }) {
    return Column(
      children: [
        SizedBox(height: responsive['iconContainerTop']),

        // Icon
        Container(
          width: responsive['iconSize'],
          height: responsive['iconSize'],
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconData,
            size: responsive['iconSize'] * 0.5,
            color: iconColor,
          ),
        ),

        SizedBox(height: responsive['iconContainerBottom']),

        // Title
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive['horizontalPadding'],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: responsive['titleFontSize'],
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        SizedBox(height: responsive['titleBottom']),

        // Subtitle
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive['horizontalPadding'],
          ),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: responsive['subtitleFontSize'],
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        SizedBox(height: responsive['subtitleBottom']),

        // PIN Fields
        _buildPinFields(isConfirm, responsive),

        SizedBox(height: responsive['pinFieldsBottom']),

        // Button or Loading
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive['horizontalPadding'],
          ),
          child: _isLoading && isConfirm
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF246AFD)),
                )
              : SizedBox(
                  width: double.infinity,
                  height: responsive['buttonHeight'],
                  child: ElevatedButton(
                    onPressed: onButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF246AFD),
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: onButtonPressed != null ? 2 : 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        buttonText,
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

        SizedBox(height: responsive['buttonBottom']),

        // Clear Button
        TextButton(
          onPressed: () => _clearPin(isConfirm),
          child: Text(
            'Hapus',
            style: TextStyle(
              fontSize: responsive['subtitleFontSize'],
              color: const Color(0xFF246AFD),
            ),
          ),
        ),

        SizedBox(height: responsive['bottomSpacing']),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = _getResponsiveValues(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _isConfirmStep ? 'Konfirmasi PIN' : 'Setup PIN',
            style: TextStyle(
              fontSize: responsive['buttonFontSize'],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isConfirmStep) {
              _goBackToSetup();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Stack(
                        children: [
                          // Setup PIN Step
                          if (!_isConfirmStep)
                            _buildStepContent(
                              isConfirm: false,
                              responsive: responsive,
                              title: 'Buat PIN Baru',
                              subtitle:
                                  'Buat PIN 6 digit untuk keamanan aplikasi Anda',
                              buttonText: 'Lanjutkan',
                              onButtonPressed: _getPin(false).length == 6
                                  ? _proceedToConfirm
                                  : null,
                              iconData: Icons.security,
                              iconColor: const Color(0xFF246AFD),
                            ),

                          // Confirm PIN Step
                          SlideTransition(
                            position: _slideAnimation,
                            child: _isConfirmStep
                                ? _buildStepContent(
                                    isConfirm: true,
                                    responsive: responsive,
                                    title: 'Konfirmasi PIN',
                                    subtitle:
                                        'Masukkan kembali PIN untuk konfirmasi',
                                    buttonText: 'Simpan PIN',
                                    onButtonPressed: _getPin(true).length == 6
                                        ? _setupPin
                                        : null,
                                    iconData: Icons.check_circle_outline,
                                    iconColor: Colors.green,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
