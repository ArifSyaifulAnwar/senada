// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';

import 'package:absensikaryawan/Services/employee_service.dart';
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HalamanListEmployeeAdmin extends StatefulWidget {
  const HalamanListEmployeeAdmin({super.key});

  @override
  _HalamanListEmployeeAdminState createState() => _HalamanListEmployeeAdminState();
}

// Keep your existing EmployeeData class for UI compatibility
class EmployeeData {
  final int id;
  final String nama;
  final String email;
  final String telepon;
  final String jabatan;
  final String departemen;
  final String status;
  final String tanggalBergabung;
  final String alamat;
  final String foto;
  final String nomorKaryawan;
  final String manager;
  final List<String> skills;

  EmployeeData({
    required this.id,
    required this.nama,
    required this.email,
    required this.telepon,
    required this.jabatan,
    required this.departemen,
    required this.status,
    required this.tanggalBergabung,
    required this.alamat,
    required this.foto,
    required this.nomorKaryawan,
    required this.manager,
    required this.skills,
  });
}

class _HalamanListEmployeeAdminState extends State<HalamanListEmployeeAdmin> {
  bool isLoading = false;
  String errorMessage = '';
  String searchQuery = '';
  String selectedDepartment = 'Semua';
  String selectedStatus = 'Semua';
  String sortBy = 'Nama A-Z';

  // API Data
  List<EmployeeData> allEmployeeData = [];
  EmployeeStats? employeeStats;
  int currentPage = 1;
  int totalPages = 1;
  int totalCount = 0;

  // Text editing controller untuk search
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  // Load data dari API
  Future<void> _loadEmployeeData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Convert sortBy to API format
      String apiSortBy = _convertSortByToApi(sortBy);

      final response = await EmployeeService.getEmployeeList(
        searchQuery: searchQuery.isEmpty ? null : searchQuery,
        department: selectedDepartment == 'Semua' ? null : selectedDepartment,
        status: selectedStatus == 'Semua' ? null : selectedStatus,
        sortBy: apiSortBy,
        page: currentPage,
        pageSize: 50, // Load more data
      );

      if (response.success && response.data != null) {
        setState(() {
          allEmployeeData = response.data!.data
              .map((apiData) => apiData.toEmployeeData()).cast<EmployeeData>()
              .toList();
          employeeStats = response.data!.stats;
          totalPages = response.data!.totalPages;
          totalCount = response.data!.totalCount;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response.message;
          isLoading = false;
        });
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  // Lanjutan dari _convertSortByToApi method dan implementasi lengkap

  String _convertSortByToApi(String uiSortBy) {
    switch (uiSortBy) {
      case 'Nama A-Z':
        return 'name_asc';
      case 'Nama Z-A':
        return 'name_desc';
      case 'Tanggal Bergabung (Terbaru)':
        return 'join_date_desc';
      case 'Tanggal Bergabung (Terlama)':
        return 'join_date_asc';
      default:
        return 'name_asc';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Fungsi untuk refresh data
  Future<void> _refreshData() async {
    currentPage = 1;
    await _loadEmployeeData();
  }

  // Fungsi untuk search dengan debounce
  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });

    // Debounce untuk menghindari terlalu banyak API call
    Future.delayed(Duration(milliseconds: 500), () {
      if (searchQuery == value) {
        _refreshData();
      }
    });
  }

  // Fungsi untuk mendapatkan data yang sudah difilter (untuk local filtering jika diperlukan)
  List<EmployeeData> getFilteredEmployeeData() {
    return allEmployeeData; // Data sudah difilter di server
  }

  // Fungsi untuk mendapatkan statistik karyawan
  Map<String, int> getEmployeeStats() {
    if (employeeStats != null) {
      return {
        'Total': employeeStats!.totalEmployees,
        'Aktif': employeeStats!.activeEmployees,
        'Cuti': employeeStats!.onLeaveEmployees,
        'Non-Aktif': employeeStats!.inactiveEmployees,
      };
    }

    return {
      'Total': allEmployeeData.length,
      'Aktif': 0,
      'Cuti': 0,
      'Non-Aktif': 0,
    };
  }

  // Fungsi untuk format tanggal
  String _formatTanggal(String tanggal) {
    try {
      DateTime date = DateTime.parse(tanggal);
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return tanggal;
    }
  }

  // Fungsi untuk mendapatkan warna status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'aktif':
        return Colors.green;
      case 'cuti':
        return Colors.orange;
      case 'non-aktif':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Fungsi untuk mendapatkan icon status
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'aktif':
        return Icons.check_circle;
      case 'cuti':
        return Icons.access_time;
      case 'non-aktif':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  // Responsive functions
  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return baseFontSize * scale.clamp(0.85, 1.15);
  }

  double _getResponsivePadding(BuildContext context, double basePadding) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return basePadding * scale.clamp(0.85, 1.1);
  }

  double _getResponsiveIconSize(BuildContext context, double baseIconSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 375;
    return baseIconSize * scale.clamp(0.85, 1.1);
  }

  // Widget untuk statistik box
  Widget _buildStatBox(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 12),
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk search bar
  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: const Color(0xFF94A3B8), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari karyawan...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: _getResponsiveFontSize(context, 14),
                ),
              ),
              style: TextStyle(fontSize: _getResponsiveFontSize(context, 14)),
              onChanged: _onSearchChanged,
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  searchQuery = '';
                  _searchController.clear();
                });
                _refreshData();
              },
              child: Icon(
                Icons.clear,
                color: const Color(0xFF94A3B8),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  // Widget untuk employee card
  Widget _buildEmployeeCard(EmployeeData employee) {
    return GestureDetector(
      onTap: () => _showDetailEmployee(employee),
      child: Container(
        margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 12)),
        padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: _buildProfileImage(employee.foto, 60),
                  ),
                ),
                SizedBox(width: _getResponsivePadding(context, 16)),

                // Info utama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              employee.nama,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 16),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: _getResponsivePadding(context, 8),
                              vertical: _getResponsivePadding(context, 4),
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                employee.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(employee.status),
                                  size: 12,
                                  color: _getStatusColor(employee.status),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  employee.status,
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(
                                      context,
                                      10,
                                    ),
                                    fontWeight: FontWeight.w500,
                                    color: _getStatusColor(employee.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        employee.jabatan,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        employee.departemen,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: _getResponsivePadding(context, 12)),

            // Info detail
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.badge,
                            size: _getResponsiveIconSize(context, 14),
                            color: const Color(0xFF64748B),
                          ),
                          SizedBox(width: 4),
                          Text(
                            employee.nomorKaryawan,
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: _getResponsiveIconSize(context, 14),
                            color: const Color(0xFF64748B),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              employee.email,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 12),
                                color: const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: _getResponsiveIconSize(context, 14),
                          color: const Color(0xFF64748B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          employee.tanggalBergabung.isNotEmpty
                              ? _formatTanggal(employee.tanggalBergabung)
                              : '-',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? photoBase64, double size) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(size);
          },
        );
      } catch (e) {
        return _buildDefaultAvatar(size);
      }
    } else {
      return _buildDefaultAvatar(size);
    }
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.blue[100],
      child: Icon(Icons.person, size: size * 0.5, color: Colors.blue[600]),
    );
  }

  // Widget untuk detail employee dengan loading detail dari API
  void _showDetailEmployee(EmployeeData employee) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Get detailed employee data from API
      final response = await EmployeeService.getEmployeeDetail(id: employee.id);

      Navigator.pop(context); // Close loading dialog

      if (response.success && response.data != null) {
        final detailedEmployee = response.data!.toEmployeeData();
        _showDetailBottomSheet(detailedEmployee as EmployeeData);
      } else {
        _showErrorSnackBar(
          'Gagal mengambil detail karyawan: ${response.message}',
        );
        // Show with existing data if API fails
        _showDetailBottomSheet(employee);
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('Terjadi kesalahan: $e');
      // Show with existing data if API fails
      _showDetailBottomSheet(employee);
    }
  }

  void _showDetailBottomSheet(EmployeeData employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Header dengan foto dan info utama
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: _buildProfileImage(employee.foto, 80),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.nama,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          employee.jabatan,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        Text(
                          employee.departemen,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              employee.status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(employee.status),
                                size: 16,
                                color: _getStatusColor(employee.status),
                              ),
                              SizedBox(width: 6),
                              Text(
                                employee.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _getStatusColor(employee.status),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Detail informasi
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailSection('Informasi Personal', [
                      _buildDetailItem(
                        'ID Karyawan',
                        employee.nomorKaryawan,
                        Icons.badge,
                        Colors.blue,
                      ),
                      _buildDetailItemWithAction(
                        'Email',
                        employee.email,
                        Icons.email,
                        Colors.green,
                        onTap: () => _sendEmail(employee.email),
                        actionIcon: Icons.mail_outline,
                        actionColor: Colors.blue,
                      ),
                      _buildDetailItemWithAction(
                        'Telepon',
                        employee.telepon.isNotEmpty
                            ? employee.telepon
                            : 'Tidak ada data',
                        Icons.phone,
                        Colors.orange,
                        onTap: employee.telepon.isNotEmpty
                            ? () => _sendWhatsApp(employee.telepon)
                            : null,
                        actionIcon: Icons.chat,
                        actionColor: Colors.green,
                      ),
                      _buildDetailItem(
                        'Alamat',
                        employee.alamat.isNotEmpty
                            ? employee.alamat
                            : 'Tidak ada data',
                        Icons.location_on,
                        Colors.red,
                      ),
                    ]),

                    SizedBox(height: 16),

                    _buildDetailSection('Informasi Pekerjaan', [
                      _buildDetailItem(
                        'Departemen',
                        employee.departemen,
                        Icons.business,
                        Colors.purple,
                      ),
                      _buildDetailItem(
                        'Manager',
                        employee.manager.isNotEmpty
                            ? employee.manager
                            : 'Tidak ada data',
                        Icons.supervisor_account,
                        Colors.cyan,
                      ),
                      _buildDetailItem(
                        'Tanggal Bergabung',
                        employee.tanggalBergabung.isNotEmpty
                            ? _formatTanggal(employee.tanggalBergabung)
                            : 'Tidak ada data',
                        Icons.calendar_today,
                        Colors.teal,
                      ),
                    ]),

                    SizedBox(height: 16),

                    if (employee.skills.isNotEmpty)
                      _buildDetailSection('Skills & Keahlian', [
                        _buildSkillsList(employee.skills),
                      ]),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                      label: Text('Tutup'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Quick action buttons
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => _sendEmail(employee.email),
                      icon: Icon(Icons.email_outlined, color: Colors.blue),
                      tooltip: 'Kirim Email',
                    ),
                  ),
                  SizedBox(width: 8),
                  if (employee.telepon.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _sendWhatsApp(employee.telepon),
                        icon: Icon(Icons.chat, color: Colors.green),
                        tooltip: 'WhatsApp',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItemWithAction(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    IconData? actionIcon,
    Color? actionColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Action button di kanan
          if (onTap != null && actionIcon != null && value != 'Tidak ada data')
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (actionColor ?? color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(actionIcon, size: 20, color: actionColor ?? color),
              ),
            ),
        ],
      ),
    );
  }

  // Method untuk mengirim email
  void _sendEmail(String email) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {'subject': 'Hello', 'body': 'Hi there!'},
      );

      if (await launchUrl(emailUri)) {
        // Success
      } else {
        _showErrorSnackBar('Tidak dapat membuka aplikasi email');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  // Method untuk mengirim WhatsApp
  void _sendWhatsApp(String phoneNumber) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Add country code if not present
      if (!cleanPhone.startsWith('+')) {
        if (cleanPhone.startsWith('0')) {
          cleanPhone = '+62${cleanPhone.substring(1)}';
        } else if (cleanPhone.startsWith('62')) {
          cleanPhone = '+$cleanPhone';
        } else {
          cleanPhone = '+62$cleanPhone';
        }
      }

      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone');

      if (await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        // Success
      } else {
        _showErrorSnackBar('WhatsApp tidak terinstall atau nomor tidak valid');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsList(List<String> skills) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.psychology, color: Colors.blue, size: 20),
              ),
              SizedBox(width: 16),
              Text(
                'Skills & Keahlian',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((skill) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, int> stats = getEmployeeStats();
    List<EmployeeData> filteredData = getFilteredEmployeeData();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Daftar Karyawan',
          style: TextStyle(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: _getResponsiveFontSize(context, 18),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: _getResponsivePadding(context, 16)),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(_getResponsivePadding(context, 8)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.filter_list,
                  color: const Color(0xFF3B82F6),
                  size: _getResponsiveIconSize(context, 20),
                ),
              ),
              onPressed: _showFilterSheet,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message
              if (errorMessage.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            errorMessage = '';
                          });
                        },
                        icon: Icon(Icons.close, color: Colors.red, size: 18),
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

              // Statistics Cards
              GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final statData = [
                    {
                      'title': 'Total Karyawan',
                      'value': stats['Total'].toString(),
                      'color': Colors.blue,
                      'icon': Icons.people,
                    },
                    {
                      'title': 'Karyawan Aktif',
                      'value': stats['Aktif'].toString(),
                      'color': Colors.green,
                      'icon': Icons.check_circle,
                    },
                    {
                      'title': 'Sedang Cuti',
                      'value': stats['Cuti'].toString(),
                      'color': Colors.orange,
                      'icon': Icons.access_time,
                    },
                    {
                      'title': 'Non-Aktif',
                      'value': stats['Non-Aktif'].toString(),
                      'color': Colors.red,
                      'icon': Icons.cancel,
                    },
                  ];

                  return _buildStatBox(
                    statData[index]['title'] as String,
                    statData[index]['value'] as String,
                    statData[index]['color'] as Color,
                    statData[index]['icon'] as IconData,
                  );
                },
              ),

              SizedBox(height: _getResponsivePadding(context, 24)),

              // Search Bar
              _buildSearchBar(),

              SizedBox(height: _getResponsivePadding(context, 20)),

              // Header dengan jumlah karyawan dan sort
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Karyawan',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 18),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _getResponsivePadding(context, 12),
                          vertical: _getResponsivePadding(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${filteredData.length} karyawan',
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showSortSheet,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(
                            Icons.sort,
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: _getResponsivePadding(context, 16)),

              // Employee List
              if (isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                )
              else if (filteredData.isEmpty && errorMessage.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    return _buildEmployeeCard(filteredData[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 40),
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Tidak ada karyawan ditemukan',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coba ubah filter atau kata kunci pencarian',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: const Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh),
            label: Text('Muat Ulang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Filter Karyawan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Departemen Filter
                    Text(
                      'Departemen',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            'Semua',
                            'IT Development',
                            'Design',
                            'Human Resources',
                            'Marketing',
                          ].map((dept) {
                            return FilterChip(
                              label: Text(dept),
                              selected: selectedDepartment == dept,
                              onSelected: (selected) {
                                setModalState(() {
                                  selectedDepartment = dept;
                                });
                              },
                            );
                          }).toList(),
                    ),

                    SizedBox(height: 24),

                    // Status Filter
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Semua', 'Aktif', 'Cuti', 'Non-Aktif'].map((
                        status,
                      ) {
                        return FilterChip(
                          label: Text(status),
                          selected: selectedStatus == status,
                          onSelected: (selected) {
                            setModalState(() {
                              selectedStatus = status;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 32),

                    // Apply Filter Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            // Filter akan di-apply ke API
                          });
                          Navigator.pop(context);
                          _refreshData(); // Reload data dengan filter baru
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Terapkan Filter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Urutkan Berdasarkan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ...[
                'Nama A-Z',
                'Nama Z-A',
                'Tanggal Bergabung (Terbaru)',
                'Tanggal Bergabung (Terlama)',
              ].map((sort) {
                return ListTile(
                  leading: Icon(
                    sortBy == sort
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: sortBy == sort ? Color(0xFF3B82F6) : Colors.grey,
                  ),
                  title: Text(sort),
                  onTap: () {
                    setState(() {
                      sortBy = sort;
                    });
                    Navigator.pop(context);
                    _refreshData(); // Reload data dengan urutan baru
                  },
                );
              }),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
