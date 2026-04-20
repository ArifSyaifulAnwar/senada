// emergency_contact_screen.dart (Updated with API integration)
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Services/emergencycontactservice.dart';
import 'package:flutter/material.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/keamanan/addemergencycontact.dart';

class EmergencyContactScreen extends StatefulWidget {
  final String userId; // Add userId parameter

  const EmergencyContactScreen({super.key, required this.userId});

  @override
  _EmergencyContactScreenState createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _loadEmergencyContacts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadEmergencyContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = EmergencyContactService();
      final response = await service.getEmergencyContacts(widget.userId);

      if (response.success && response.data != null) {
        setState(() {
          _emergencyContacts = response.data!;
          _isLoading = false;
        });
        _controller.forward();
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  void _addNewContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmergencyContactScreen(userId: widget.userId),
      ),
    );

    if (result != null && result == true) {
      // Reload contacts after adding new one
      _loadEmergencyContacts();
    }
  }

  void _editContact(EmergencyContact contact) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmergencyContactScreen(
          userId: widget.userId,
          contactToEdit: contact,
        ),
      ),
    );

    if (result != null && result == true) {
      // Reload contacts after editing
      _loadEmergencyContacts();
    }
  }

  void _deleteContact(int contactId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Hapus Kontak'),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus kontak darurat ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteContact(contactId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteContact(int contactId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final service = EmergencyContactService();
      final response = await service.deleteEmergencyContact(
        contactId,
        widget.userId,
      );

      Navigator.pop(context); // Close loading dialog

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Reload contacts
        _loadEmergencyContacts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _makeContactPrimary(int contactId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final service = EmergencyContactService();
      final response = await service.setPrimaryContact(
        contactId,
        widget.userId,
      );

      Navigator.pop(context); // Close loading dialog

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Reload contacts
        _loadEmergencyContacts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildEmergencyContactCard(EmergencyContact contact) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: contact.isPrimary
              ? Border.all(color: Color(0xFF007AFF), width: 2)
              : Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan nama dan aksi
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Text(
                        contact.name.split(' ').map((n) => n[0]).take(2).join(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Info kontak
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (contact.isPrimary)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFF007AFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'UTAMA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          contact.relationship,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Menu aksi
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _editContact(contact);
                          break;
                        case 'primary':
                          if (!contact.isPrimary) {
                            _makeContactPrimary(contact.id);
                          }
                          break;
                        case 'delete':
                          _deleteContact(contact.id);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (!contact.isPrimary)
                        PopupMenuItem(
                          value: 'primary',
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Jadikan Utama'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Detail kontak
              _buildContactDetail(
                icon: Icons.phone,
                label: 'Nomor Telepon',
                value: contact.phoneNumber,
                onTap: () {},
              ),

              if (contact.email != null && contact.email!.isNotEmpty)
                _buildContactDetail(
                  icon: Icons.email,
                  label: 'Email',
                  value: contact.email!,
                  onTap: () {},
                ),

              if (contact.address != null && contact.address!.isNotEmpty)
                _buildContactDetail(
                  icon: Icons.location_on,
                  label: 'Alamat',
                  value: contact.address!,
                  isLast: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactDetail({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: Colors.grey[600]),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[200], indent: 36),
      ],
    );
  }

  Widget _buildAddContactButton() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 24, bottom: 16),
      child: ElevatedButton.icon(
        onPressed: _addNewContact,
        icon: Icon(Icons.add, size: 20),
        label: Text(
          'Tambahkan Kontak Darurat',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF007AFF),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Color(0xFF007AFF).withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Terjadi kesalahan',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadEmergencyContacts,
            child: Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Memuat kontak darurat...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Kontak Darurat',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black87, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadEmergencyContacts,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingWidget()
            : _errorMessage != null
            ? _buildErrorWidget()
            : SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header info
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.emergency,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kontak Darurat',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_emergencyContacts.length} kontak tersimpan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Tips
                    if (_emergencyContacts.isEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[600],
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tambahkan kontak darurat untuk situasi mendesak',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Daftar kontak darurat
                      ...List.generate(
                        _emergencyContacts.length,
                        (index) => _buildEmergencyContactCard(
                          _emergencyContacts[index],
                        ),
                      ),

                    // Button tambah kontak
                    _buildAddContactButton(),

                    // Info tambahan
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.orange[600],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tips Kontak Darurat',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            '• Pastikan informasi kontak selalu terbaru\n'
                            '• Tambahkan minimal 2 kontak darurat\n'
                            '• Sertakan kontak medis jika diperlukan\n'
                            '• Pilih orang yang mudah dihubungi 24 jam',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}
