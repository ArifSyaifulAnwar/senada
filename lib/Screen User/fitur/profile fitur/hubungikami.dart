// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';

class HalamanHubungiKami extends StatefulWidget {
  const HalamanHubungiKami({super.key});

  @override
  _HalamanHubungiKamiState createState() => _HalamanHubungiKamiState();
}

class ContactChannel {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String contactInfo;
  final String availability;
  final VoidCallback onTap;

  ContactChannel({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.contactInfo,
    required this.availability,
    required this.onTap,
  });
}

class OfficeBranch {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String hours;
  final double latitude;
  final double longitude;

  OfficeBranch({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.hours,
    required this.latitude,
    required this.longitude,
  });
}

class _HalamanHubungiKamiState extends State<HalamanHubungiKami> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedDepartment = 'Umum';
  bool _isLoading = false;

  final List<OfficeBranch> branches = [
    OfficeBranch(
      name: 'Kantor Pusat',
      address:
          'Gedung Tekno Plaza Lt. 15, Jl. Sudirman No. 123, Jakarta Selatan',
      phone: '(021) 1234-5678',
      email: 'info@teknusa.co.id',
      hours: 'Senin-Jumat: 08:00-17:00 WIB',
      latitude: -6.2088,
      longitude: 106.8456,
    ),
    OfficeBranch(
      name: 'Kantor Cabang Bandung',
      address: 'Jl. Pasteur No. 25, Bandung',
      phone: '(022) 8765-4321',
      email: 'bdg@teknusa.co.id',
      hours: 'Senin-Jumat: 08:00-17:00 WIB',
      latitude: -6.9175,
      longitude: 107.6191,
    ),
    OfficeBranch(
      name: 'Kantor Cabang Surabaya',
      address: 'Jl. Pemuda No. 78, Surabaya',
      phone: '(031) 9876-5432',
      email: 'sby@teknusa.co.id',
      hours: 'Senin-Jumat: 08:00-17:00 WIB',
      latitude: -7.2575,
      longitude: 112.7521,
    ),
  ];

  List<ContactChannel> getContactChannels() {
    return [
      ContactChannel(
        name: 'Call Center',
        description: 'Hubungi nomor telepon utama kami',
        icon: Icons.phone,
        color: Colors.blue,
        contactInfo: '1500 123',
        availability: '24/7',
        onTap: () => _openPhoneSupport(),
      ),
      ContactChannel(
        name: 'WhatsApp',
        description: 'Kirim pesan melalui WhatsApp',
        icon: Icons.message,
        color: Colors.green,
        contactInfo: '+62 812-3456-7890',
        availability: 'Senin-Jumat 08:00-17:00',
        onTap: () => _openWhatsAppSupport(),
      ),
      ContactChannel(
        name: 'Email',
        description: 'Kirim email ke alamat resmi',
        icon: Icons.email,
        color: Colors.red,
        contactInfo: 'info@teknusa.co.id',
        availability: 'Respon dalam 24 jam',
        onTap: () => _openEmailSupport(),
      ),
      ContactChannel(
        name: 'Live Chat Website',
        description: 'Chat langsung dari website kami',
        icon: Icons.chat,
        color: Colors.purple,
        contactInfo: 'www.teknusa.co.id',
        availability: 'Senin-Jumat 08:00-17:00',
        onTap: () => _openLiveChat(),
      ),
      ContactChannel(
        name: 'Helpdesk IT',
        description: 'Dukungan teknis IT',
        icon: Icons.computer,
        color: Colors.orange,
        contactInfo: 'it-support@teknusa.co.id',
        availability: 'Senin-Jumat 08:00-17:00',
        onTap: () => _openITHelpdesk(),
      ),
      ContactChannel(
        name: 'SOC Security',
        description: 'Melaporkan insiden keamanan',
        icon: Icons.security,
        color: Colors.teal,
        contactInfo: 'soc@teknusa.co.id',
        availability: '24/7',
        onTap: () => _openSecuritySupport(),
      ),
    ];
  }

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

  Widget _buildInfoBanner() {
    return Container(
      margin: EdgeInsets.all(_getResponsivePadding(context, 20)),
      padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF3B82F6), size: 24),
          SizedBox(width: _getResponsivePadding(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bantuan 24/7 Tersedia',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Untuk masalah urgent, harap hubungi call center kami yang tersedia 24 jam',
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
    );
  }

  Widget _buildContactChannelCard(ContactChannel channel) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: channel.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: channel.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(channel.icon, color: channel.color, size: 24),
              ),
              SizedBox(width: _getResponsivePadding(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      channel.description,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.contact_page,
                          size: 14,
                          color: channel.color,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            channel.contactInfo,
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              color: channel.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: const Color(0xFF94A3B8),
                        ),
                        SizedBox(width: 4),
                        Text(
                          channel.availability,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 12),
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Form Kontak',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: _getResponsivePadding(context, 16)),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Lengkap',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Harap masukkan nama lengkap';
              }
              return null;
            },
          ),
          SizedBox(height: _getResponsivePadding(context, 12)),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Alamat Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Harap masukkan alamat email';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Alamat email tidak valid';
              }
              return null;
            },
          ),
          SizedBox(height: _getResponsivePadding(context, 12)),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Nomor Telepon',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Harap masukkan nomor telepon';
              }
              if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                return 'Nomor telepon hanya boleh angka';
              }
              if (value.length < 8 || value.length > 15) {
                return 'Nomor telepon tidak valid';
              }
              return null;
            },
          ),
          SizedBox(height: _getResponsivePadding(context, 12)),
          DropdownButtonFormField<String>(
            value: _selectedDepartment,
            decoration: InputDecoration(
              labelText: 'Departemen Tujuan',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items:
                <String>[
                  'Umum',
                  'HRD',
                  'IT Support',
                  'Finance',
                  'Marketing',
                  'Security',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedDepartment = newValue!;
              });
            },
          ),
          SizedBox(height: _getResponsivePadding(context, 12)),
          TextFormField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Subjek Pesan',
              prefixIcon: Icon(Icons.subject),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Harap masukkan subjek pesan';
              }
              return null;
            },
          ),
          SizedBox(height: _getResponsivePadding(context, 12)),
          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Pesan',
              prefixIcon: Icon(Icons.message),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Harap masukkan pesan Anda';
              }
              if (value.length < 20) {
                return 'Pesan terlalu pendek, harap jelaskan lebih detail';
              }
              return null;
            },
          ),
          SizedBox(height: _getResponsivePadding(context, 24)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitContactForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : Text(
                      'Kirim Pesan',
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeBranchTile(OfficeBranch branch) {
    return Card(
      margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 24),
                SizedBox(width: _getResponsivePadding(context, 8)),
                Text(
                  branch.name,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            SizedBox(height: _getResponsivePadding(context, 12)),
            Text(
              branch.address,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: _getResponsivePadding(context, 8)),
            Divider(height: 1),
            SizedBox(height: _getResponsivePadding(context, 8)),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: const Color(0xFF64748B)),
                SizedBox(width: _getResponsivePadding(context, 8)),
                Text(
                  branch.phone,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            SizedBox(height: _getResponsivePadding(context, 4)),
            Row(
              children: [
                Icon(Icons.email, size: 16, color: const Color(0xFF64748B)),
                SizedBox(width: _getResponsivePadding(context, 8)),
                Expanded(
                  child: Text(
                    branch.email,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: _getResponsivePadding(context, 4)),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: const Color(0xFF64748B)),
                SizedBox(width: _getResponsivePadding(context, 8)),
                Text(
                  branch.hours,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 14),
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            SizedBox(height: _getResponsivePadding(context, 12)),
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Membuka peta lokasi ${branch.name}...'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: _getResponsivePadding(context, 150),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 40, color: Colors.grey[600]),
                      SizedBox(height: 8),
                      Text(
                        'Map Lokasi',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Tap untuk membuka peta',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitContactForm() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      Future.delayed(Duration(seconds: 2), () {
        setState(() {
          _isLoading = false;
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Pesan Terkirim!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terima kasih telah menghubungi kami. Kami akan segera merespon permintaan Anda.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nomor Tiket:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'TK${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Simpan nomor tiket ini untuk melacak status permintaan Anda.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _formKey.currentState!.reset();
                    _nameController.clear();
                    _emailController.clear();
                    _phoneController.clear();
                    _subjectController.clear();
                    _messageController.clear();
                    setState(() {
                      _selectedDepartment = 'Umum';
                    });
                  },
                  child: Text(
                    'Tutup',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            );
          },
        );
      });
    }
  }

  // Support channel methods
  void _openPhoneSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.phone, color: Colors.white),
            SizedBox(width: 8),
            Text('Mengarahkan ke aplikasi telepon...'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _openWhatsAppSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.message, color: Colors.white),
            SizedBox(width: 8),
            Text('Mengarahkan ke WhatsApp...'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openEmailSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.email, color: Colors.white),
            SizedBox(width: 8),
            Text('Mengarahkan ke aplikasi email...'),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _openLiveChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.chat, color: Colors.white),
            SizedBox(width: 8),
            Text('Mengarahkan ke live chat...'),
          ],
        ),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _openITHelpdesk() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.computer, color: Colors.white),
            SizedBox(width: 8),
            Text('Mengarahkan ke halaman IT Helpdesk...'),
          ],
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _openSecuritySupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.security, color: Colors.white),
            SizedBox(width: 8),
            Text('Mengarahkan ke halaman Security Support...'),
          ],
        ),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Hubungi Kami',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
            fontSize: _getResponsiveFontSize(context, 18),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.contact_support, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kami siap membantu Anda kapan saja!'),
                  backgroundColor: const Color(0xFF3B82F6),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Info Banner
            _buildInfoBanner(),

            // Body Content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _getResponsivePadding(context, 20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Channels
                  Text(
                    'Pilih Cara Menghubungi',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 18),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: _getResponsivePadding(context, 16)),
                  Column(
                    children: getContactChannels()
                        .map((channel) => _buildContactChannelCard(channel))
                        .toList(),
                  ),

                  SizedBox(height: _getResponsivePadding(context, 24)),

                  // Office Branches
                  Text(
                    'Kantor Kami',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 18),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: _getResponsivePadding(context, 16)),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: branches.length,
                    itemBuilder: (context, index) {
                      return _buildOfficeBranchTile(branches[index]);
                    },
                  ),

                  SizedBox(height: _getResponsivePadding(context, 24)),

                  // Contact Form
                  _buildContactForm(),

                  SizedBox(height: _getResponsivePadding(context, 24)),
                  SizedBox(height: _getResponsivePadding(context, 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
