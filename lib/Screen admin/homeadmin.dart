// ignore_for_file: deprecated_member_use

import 'package:absensikaryawan/Screen%20User/fitur/attendance.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/listkaryawan.dart';
import 'package:absensikaryawan/Screen%20admin/Home/homenyaadmin.dart';
import 'package:absensikaryawan/Screen%20admin/Home/profileadmin.dart';
import 'package:absensikaryawan/Screen%20admin/navbar/admin_attendance_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class HomePageAdmin extends StatefulWidget {
  const HomePageAdmin({super.key});

  @override
  State<HomePageAdmin> createState() => _HomePageAdminState();
}

class _HomePageAdminState extends State<HomePageAdmin> {
  int myCurrentIndex = 0;
  String? _userEmail;
  late Future<void> _loadData;

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userEmail = prefs.getString('Email');
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData = _loadUserEmail();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double scale = size.width / 375.0;
    final bool isWeb = _isWideScreen(context);

    List<Widget> pages = [
      const HomeScreenAdmin(), // 0 - Home
      const HalamanAdminAbsensi(), // 1 - Riwayat Absensi
      const AbsensiScreen(), // 2 - Kamera (FAB / mobile only)
      const HalamanListEmployee(), // 3 - List Karyawan
      const ProfileScreenAdmin(), // 4 - Profile
    ];

    return FutureBuilder<void>(
      future: _loadData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_userEmail == null) {
          return const Scaffold(
            body: Center(child: Text('Email tidak ditemukan')),
          );
        }

        // ── WEB: sidebar kiri, tanpa FAB & bottom nav ──
        if (isWeb) {
          return Scaffold(
            backgroundColor: const Color(0xFFFAFAFA),
            body: Row(
              children: [
                _buildWebSidebar(),
                Expanded(child: pages[myCurrentIndex]),
              ],
            ),
          );
        }

        // ── MOBILE: bottom nav + FAB ──
        return Scaffold(
          body: pages[myCurrentIndex],
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: Container(
            width: 60 * scale,
            height: 60 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2E57C9),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.4),
                  blurRadius: 12 * scale,
                  offset: Offset(0, 6 * scale),
                ),
              ],
            ),
            child: FloatingActionButton(
              backgroundColor: Colors.transparent,
              elevation: 0,
              onPressed: () => setState(() => myCurrentIndex = 2),
              child: Icon(
                Icons.camera_alt,
                size: 24 * scale,
                color: Colors.white,
              ),
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8 * scale,
            elevation: 8,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 6 * scale,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTabIcon(Icons.home_filled, 0, scale),
                  _buildTabIcon(Icons.receipt_long, 1, scale),
                  SizedBox(width: 40 * scale), // ruang tengah FAB
                  _buildTabIcon(Icons.people, 3, scale),
                  _buildTabIcon(Icons.person_outline, 4, scale),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // SIDEBAR WEB (pengganti bottom nav)
  // ─────────────────────────────────────────────

  Widget _buildWebSidebar() {
    final items = [
      _SidebarItem(icon: Icons.home_filled, label: 'Home', index: 0),
      _SidebarItem(icon: Icons.receipt_long, label: 'Absensi', index: 1),
      _SidebarItem(icon: Icons.camera_alt, label: 'Kamera', index: 2),
      _SidebarItem(icon: Icons.people, label: 'Karyawan', index: 3),
      _SidebarItem(icon: Icons.person_outline, label: 'Profil', index: 4),
    ];

    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Logo / brand
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2E57C9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.apartment, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...items.map((item) => _buildSidebarIcon(item)),
            const Spacer(),
            const Divider(height: 1),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarIcon(_SidebarItem item) {
    final isSelected = myCurrentIndex == item.index;
    return GestureDetector(
      onTap: () => setState(() => myCurrentIndex = item.index),
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2E57C9).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: isSelected ? const Color(0xFF2E57C9) : Colors.grey[500],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? const Color(0xFF2E57C9) : Colors.grey[500],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MOBILE tab icon
  // ─────────────────────────────────────────────

  Widget _buildTabIcon(IconData icon, int index, double scale) {
    final isSelected = myCurrentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => myCurrentIndex = index),
      child: Container(
        padding: EdgeInsets.all(6 * scale),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: Icon(
          icon,
          size: 24 * scale,
          color: isSelected ? const Color(0xFF2E57C9) : Colors.grey,
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final int index;
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
