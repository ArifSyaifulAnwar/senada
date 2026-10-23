import 'dart:typed_data';

import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';
import 'package:flutter/material.dart';

/// Mengambil foto secara terpisah dari daftar agar response daftar karyawan
/// tetap ringan. Endpoint menentukan perusahaan dari token peminta.
class EmployeeProfilePhoto extends StatefulWidget {
  final int employeeId;
  final double size;
  final Widget fallback;

  const EmployeeProfilePhoto({
    super.key,
    required this.employeeId,
    required this.size,
    required this.fallback,
  });

  @override
  State<EmployeeProfilePhoto> createState() => _EmployeeProfilePhotoState();
}

class _EmployeeProfilePhotoState extends State<EmployeeProfilePhoto> {
  static final Map<int, Uint8List?> _cache = {};
  static final Map<int, Future<Uint8List?>> _pending = {};

  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) {
      _bytes = null;
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await _fetch(widget.employeeId);
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _loaded = true;
      });
    }
  }

  static Future<Uint8List?> _fetch(int employeeId) {
    if (_cache.containsKey(employeeId)) return Future.value(_cache[employeeId]);

    return _pending.putIfAbsent(employeeId, () async {
      try {
        final response = await TokenService.authorizedGet(
          Uri.parse('$baseURL/api/employee/photo/$employeeId'),
          timeout: const Duration(seconds: 20),
        );
        final bytes = response.statusCode == 200 && response.bodyBytes.isNotEmpty
            ? response.bodyBytes
            : null;
        // Jangan cache kegagalan/401. Setelah token sesi diperbarui atau
        // koneksi pulih, kartu yang dibangun ulang harus dapat mencoba lagi.
        if (bytes != null) _cache[employeeId] = bytes;
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _pending.remove(employeeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _bytes == null) return widget.fallback;

    return Image.memory(
      _bytes!,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}
