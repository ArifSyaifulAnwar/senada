import 'package:absensikaryawan/Screen%20admin/Home/liveattendanceadmin.dart';
import 'package:flutter/material.dart';

/// Live Attendance memakai satu implementasi untuk User, HRD, dan Admin.
/// Data jam masuk/keluar selalu dibaca dari API, bukan disimulasikan di client.
class LiveAttendanceScreen extends StatelessWidget {
  const LiveAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const LiveAttendanceScreenAdmin();
}
