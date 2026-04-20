import 'dart:async';
import 'package:flutter/material.dart';

class NamaDisplay extends StatefulWidget {
  final String nama;
  final double scale;

  const NamaDisplay({required this.nama, required this.scale, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _NamaDisplayState createState() => _NamaDisplayState();
}

class _NamaDisplayState extends State<NamaDisplay> {
  bool _isExpanded = false;
  Timer? _timer;

  void _toggleExpand() {
    setState(() {
      _isExpanded = true;
    });

    // Cancel timer kalau sudah jalan
    _timer?.cancel();

    // Set timer untuk reset ke default setelah 3 detik
    _timer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Hapus timer saat widget dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
