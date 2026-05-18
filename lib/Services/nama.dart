// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Helper: deteksi lebar layar
// ─────────────────────────────────────────────
bool isWideScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= 768;
}

// ─────────────────────────────────────────────
// NamaDisplay
// ─────────────────────────────────────────────
class NamaDisplay extends StatefulWidget {
  final String nama;
  final double scale;

  const NamaDisplay({required this.nama, required this.scale, super.key});

  @override
  _NamaDisplayState createState() => _NamaDisplayState();
}

class _NamaDisplayState extends State<NamaDisplay> {
  bool _isExpanded = false;
  Timer? _timer;

  void _toggleExpand() {
    setState(() => _isExpanded = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isExpanded = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWideScreen(context);

    // Web/wide: tampilkan tooltip + ukuran font lebih kecil
    // Mobile: behavior lama (tap to expand)
    if (wide) {
      return Tooltip(
        message: widget.nama,
        child: Text(
          widget.nama,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16 * widget.scale, // sedikit lebih kecil di web
          ),
        ),
      );
    }

    // Mobile layout (behavior asli)
    return GestureDetector(
      onTap: _toggleExpand,
      child: Text(
        widget.nama,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _isExpanded ? 14 * widget.scale : 18 * widget.scale,
        ),
      ),
    );
  }
}
