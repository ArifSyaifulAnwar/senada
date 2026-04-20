// ignore_for_file: deprecated_member_use

import 'package:absensikaryawan/Screen%20HRD/Home/homenyahrd.dart';
import 'package:absensikaryawan/Screen%20User/fitur/attendance.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/listkaryawan.dart';
import 'package:absensikaryawan/Screen%20admin/Home/profileadmin.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Home/riwayatabsensihrd.dart';

class HomePageHRD extends StatefulWidget {
  const HomePageHRD({super.key});

  @override
  State<HomePageHRD> createState() => _HomePageHRDState();
}

class _HomePageHRDState extends State<HomePageHRD> {
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

    List<Widget> pages = [
      const HomeScreenHRD(), // Home
      const HalamanHRDAbsensi(), // Kalender
      const AbsensiScreen(), // Kamera (FAB)
      const HalamanListEmployee(), // Beach
      const ProfileScreenAdmin(), // Profile
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

        return Scaffold(
          body: pages[myCurrentIndex],
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: Container(
            width: 60 * scale, // lebih kecil
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
              onPressed: () {
                setState(() {
                  myCurrentIndex = 2;
                });
              },
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
                  SizedBox(width: 40 * scale), // ruang tengah
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

  Widget _buildTabIcon(IconData icon, int index, double scale) {
    final isSelected = myCurrentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          myCurrentIndex = index;
        });
      },
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
