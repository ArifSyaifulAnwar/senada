// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:absensikaryawan/Services/attendance_reminder_service.dart';

class PengingatAbsenScreen extends StatefulWidget {
  const PengingatAbsenScreen({super.key});

  @override
  _PengingatAbsenScreenState createState() => _PengingatAbsenScreenState();
}

class _PengingatAbsenScreenState extends State<PengingatAbsenScreen> {
  bool _enabled = true;
  bool _isLoadingInitial = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AttendanceReminderService.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _isLoadingInitial = false;
    });
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _isSaving = true);
    await AttendanceReminderService.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final padding = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengingat Absen',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 4.0,
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8.0 : 12.0,
                            vertical: 4.0,
                          ),
                          title: Text(
                            'Aktifkan Pengingat Absen',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: isSmallScreen ? 13 : 14,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              _enabled
                                  ? 'Aktif - Anda akan diingatkan lewat notifikasi'
                                  : 'Nonaktif - Tidak ada notifikasi pengingat',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                            ),
                          ),
                          value: _enabled,
                          onChanged: _isSaving ? null : _onToggle,
                          activeColor: Colors.blue,
                          secondary: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _enabled
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_off_outlined,
                                  color: _enabled ? Colors.blue : Colors.grey,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Jika sampai jam 10:00 Anda belum melakukan absen '
                              'masuk pada hari kerja Anda, aplikasi akan '
                              'mengirim notifikasi pengingat satu kali di '
                              'hari itu. Tidak muncul di hari libur/weekend '
                              'atau di luar jadwal kerja Anda.',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
