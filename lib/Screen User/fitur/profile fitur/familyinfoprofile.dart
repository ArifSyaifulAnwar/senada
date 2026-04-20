// ignore_for_file: deprecated_member_use

import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/tambahanggotakeluarga.dart';
import 'package:flutter/material.dart';

class FamilyMember {
  final String name;
  final String relationship;
  final String phone;
  final String? photoUrl;

  FamilyMember({
    required this.name,
    required this.relationship,
    required this.phone,
    this.photoUrl,
  });
}

class FamilyInfoScreen extends StatefulWidget {
  const FamilyInfoScreen({super.key});

  @override
  State<FamilyInfoScreen> createState() => _FamilyInfoScreenState();
}

class _FamilyInfoScreenState extends State<FamilyInfoScreen> {
  List<FamilyMember> familyMembers = [
    FamilyMember(
      name: "Ahmad Baharudin",
      relationship: "Ayah",
      phone: "+62 812-3456-7890",
      photoUrl: "https://placehold.co/100x100?text=AB",
    ),
    FamilyMember(
      name: "Siti Aminah",
      relationship: "Ibu",
      phone: "+62 878-9012-3456",
      photoUrl: "https://placehold.co/100x100?text=SA",
    ),
    FamilyMember(
      name: "Rina Wijaya",
      relationship: "Kakak",
      phone: "+62 823-4567-8901",
      photoUrl: "https://placehold.co/100x100?text=RW",
    ),
  ];

  void _addMember() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddFamilyMemberScreen()),
    ).then((result) {
      if (result == true) {
        // Refresh data jika berhasil menambah
        setState(() {
          // Reload family members data
        });
      }
    });
  }

  void _editMember(int index) {
    // Implement edit functionality
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Informasi Keluarga',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              // Implement refresh functionality
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.family_restroom,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Keluarga',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${familyMembers.length} anggota keluarga',
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

              const SizedBox(height: 24),

              // Daftar anggota keluarga
              ...List.generate(
                familyMembers.length,
                (index) => _buildFamilyMemberCard(familyMembers[index], index),
              ),

              // Button tambah anggota
              _buildAddMemberButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyMemberCard(FamilyMember member, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editMember(index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Photo
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(member.photoUrl!),
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 16),
              // Member Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.relationship,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.phone,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editMember(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMemberButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      child: ElevatedButton.icon(
        onPressed: _addMember,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Anggota Keluarga',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF007AFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
