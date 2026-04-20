// File: lib/widgets/face_guide_overlay.dart
// ULTRA SIMPLE VERSION - No animations for best performance

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class FaceGuideOverlay extends StatelessWidget {
  final bool isCapturing;
  final bool showGuidance;

  const FaceGuideOverlay({
    super.key,
    this.isCapturing = false,
    this.showGuidance = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final guideSize = screenSize.width * 0.65;

    return Stack(
      children: [
        // SIMPLE: Dark overlay with oval cutout
        CustomPaint(
          size: Size(screenSize.width, screenSize.height),
          painter: SimpleFaceGuidePainter(
            guideSize: guideSize,
            screenSize: screenSize,
          ),
        ),

        // SIMPLE: Static face guide border (no animation for performance)
        Center(
          child: Container(
            width: guideSize,
            height: guideSize * 1.3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.elliptical(guideSize / 2, (guideSize * 1.3) / 2),
              ),
              border: Border.all(
                color: isCapturing ? Colors.green : Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isCapturing ? Colors.green : Colors.white)
                      .withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isCapturing
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(guideSize / 2, (guideSize * 1.3) / 2),
                      ),
                      color: Colors.green.withOpacity(0.15),
                    ),
                  )
                : null,
          ),
        ),

        // SIMPLE: Corner guides (static)
        Center(
          child: SizedBox(
            width: guideSize * 0.85,
            height: guideSize * 0.85 * 1.3,
            child: Stack(
              children: [
                // Top corners
                Positioned(top: 8, left: 8, child: _buildCorner(true, true)),
                Positioned(top: 8, right: 8, child: _buildCorner(true, false)),
                // Bottom corners
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: _buildCorner(false, true),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _buildCorner(false, false),
                ),
              ],
            ),
          ),
        ),

        // SIMPLE: Instructions
        if (showGuidance)
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCapturing ? Icons.face_retouching_natural : Icons.face,
                    color: isCapturing ? Colors.green : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isCapturing
                        ? "Memproses wajah..."
                        : "Posisikan wajah dalam lingkaran",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // SIMPLE: Processing indicator
        if (isCapturing)
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Sedang memproses wajah...",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // SIMPLE: Tips overlay (only when not capturing)
        if (!isCapturing && showGuidance)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "💡 Pastikan pencahayaan cukup dan wajah menghadap kamera",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // SIMPLE: Basic corner widget
  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }
}

// OPTIMIZED: Simple face guide painter
class SimpleFaceGuidePainter extends CustomPainter {
  final double guideSize;
  final Size screenSize;

  SimpleFaceGuidePainter({required this.guideSize, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Create dark overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Create background rectangle
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create oval cutout in center
    final center = Offset(size.width / 2, size.height / 2);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: guideSize,
      height: guideSize * 1.3, // Oval shape for face
    );

    final ovalPath = Path()..addOval(ovalRect);

    // Subtract oval from background to create cutout
    final finalPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      ovalPath,
    );

    // Draw the overlay with cutout
    canvas.drawPath(finalPath, overlayPaint);

    // Add subtle gradient ring around the cutout
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.6,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: [0.0, 0.7, 1.0],
      ).createShader(ovalRect);

    canvas.drawOval(ovalRect.inflate(20), gradientPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
