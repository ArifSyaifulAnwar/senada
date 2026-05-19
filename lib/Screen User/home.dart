// ignore_for_file: deprecated_member_use

import 'package:absensikaryawan/Screen%20User/fitur/attendance.dart';
import 'package:absensikaryawan/Screen%20User/fitur/homenya.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile.dart';
import 'package:absensikaryawan/Screen%20User/fitur/riwayatabsensi.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/listkaryawan.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double scale = size.width / 375.0;
    final isWeb = _isWide(context);

    final List<Widget> pages = [
      const HomeScreen(),
      const HalamanRiwayatAbsensi(),
      const AbsensiScreen(showBackButton: false),
      const HalamanListEmployee(),
      const ProfileScreen(),
    ];

    // Nav item definitions
    final navItems = [
      _NavItem(Icons.home_filled, Icons.home_outlined, 'Home'),
      _NavItem(Icons.receipt_long, Icons.receipt_long_outlined, 'Riwayat'),
      _NavItem(Icons.camera_alt, Icons.camera_alt_outlined, 'Absensi'),
      _NavItem(Icons.people, Icons.people_outlined, 'Karyawan'),
      _NavItem(Icons.person, Icons.person_outline, 'Profil'),
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

        if (isWeb) {
          return _buildWebLayout(pages, navItems);
        }
        return _buildMobileLayout(pages, navItems, scale);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB LAYOUT — NavigationRail kiri + konten kanan
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWebLayout(List<Widget> pages, List<_NavItem> navItems) {
    return Scaffold(
      body: Row(
        children: [
          // ── NavigationRail ──────────────────────────────────
          NavigationRail(
            backgroundColor: Colors.white,
            selectedIndex: myCurrentIndex,
            onDestinationSelected: (i) => setState(() => myCurrentIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E57C9).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Color(0xFF2E57C9),
                  size: 22,
                ),
              ),
            ),
            selectedIconTheme: const IconThemeData(
              color: Color(0xFF2E57C9),
              size: 24,
            ),
            unselectedIconTheme: IconThemeData(
              color: Colors.grey[500],
              size: 22,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF2E57C9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
            indicatorColor: const Color(0xFF2E57C9).withOpacity(0.1),
            destinations: navItems
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.iconOutlined),
                    selectedIcon: Icon(item.iconFilled),
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          // Divider vertikal
          Container(width: 1, color: Colors.grey.shade200),
          // ── Konten ─────────────────────────────────────────
          Expanded(
            child: IndexedStack(index: myCurrentIndex, children: pages),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT (layout asli — BottomAppBar + FAB)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(
    List<Widget> pages,
    List<_NavItem> navItems,
    double scale,
  ) {
    return Scaffold(
      body: pages[myCurrentIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
          child: Icon(Icons.camera_alt, size: 24 * scale, color: Colors.white),
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
              SizedBox(width: 40 * scale),
              _buildTabIcon(Icons.people, 3, scale),
              _buildTabIcon(Icons.person_outline, 4, scale),
            ],
          ),
        ),
      ),
    );
  }

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

class _NavItem {
  final IconData iconFilled;
  final IconData iconOutlined;
  final String label;
  const _NavItem(this.iconFilled, this.iconOutlined, this.label);
}
