// Fixed version of educationscreen.dart with type errors resolved

// ignore_for_file: deprecated_member_use
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/addeducatioscreen.dart';
import 'package:flutter/material.dart';

class EducationExperienceScreen extends StatefulWidget {
  const EducationExperienceScreen({super.key});

  @override
  State<EducationExperienceScreen> createState() =>
      _EducationExperienceScreenState();
}

class _EducationExperienceScreenState extends State<EducationExperienceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Education> educationList = [
    Education(
      institution: "Universitas Indonesia",
      degree: "Sarjana Teknik",
      field: "Teknik Informatika",
      period: "2018 - 2022",
      grade: "3.75",
      type: 'education',
    ),
    Education(
      institution: "SMA Negeri 1 Jakarta",
      degree: "SMA",
      field: "IPA",
      period: "2015 - 2018",
      grade: "89.50",
      type: 'education',
    ),
  ];

  List<Experience> experienceList = [
    Experience(
      company: "PT. Teknologi Digital Indonesia",
      position: "Mobile Developer",
      period: "Jan 2023 - Sekarang",
      description:
          "Mengembangkan aplikasi mobile menggunakan Flutter dan React Native",
      type: 'experience',
    ),
    Experience(
      company: "CV. Solusi IT",
      position: "Junior Developer",
      period: "Jun 2022 - Des 2022",
      description: "Pengembangan web menggunakan Laravel dan Vue.js",
      type: 'experience',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addEducation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEducationExperienceScreen(type: 'education'),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {
          // Reload education data
        });
      }
    });
  }

  void _addExperience() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEducationExperienceScreen(type: 'experience'),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {
          // Reload experience data
        });
      }
    });
  }

  void _editEducation(int index) {
    // Fix: Check bounds and ensure the index is valid
    if (index >= 0 && index < educationList.length) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEducationExperienceScreen(
            type: 'education',
            educationToEdit: educationList[index], // This is now properly typed
          ),
        ),
      ).then((result) {
        if (result == true) {
          setState(() {
            // Reload education data
          });
        }
      });
    }
  }

  void _editExperience(int index) {
    // Fix: Check bounds and ensure the index is valid
    if (index >= 0 && index < experienceList.length) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEducationExperienceScreen(
            type: 'experience',
            experienceToEdit:
                experienceList[index], // This is now properly typed
          ),
        ),
      ).then((result) {
        if (result == true) {
          setState(() {
            // Reload experience data
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Pendidikan & Pengalaman',
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
              setState(() {
                // Implement refresh functionality
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: Colors.grey[600],
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: const Color(0xFF007AFF),
          indicatorWeight: 3,
          tabs: [
            Tab(icon: Icon(Icons.school_outlined), text: 'Pendidikan'),
            Tab(icon: Icon(Icons.work_outline), text: 'Pengalaman'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab Pendidikan
            _buildEducationTab(),
            // Tab Pengalaman
            _buildExperienceTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationTab() {
    return SingleChildScrollView(
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
                    Icons.school,
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
                        'Riwayat Pendidikan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${educationList.length} riwayat pendidikan',
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

          // Daftar pendidikan
          ...List.generate(
            educationList.length,
            (index) => _buildEducationCard(educationList[index], index),
          ),

          // Button tambah pendidikan
          _buildAddEducationButton(),
        ],
      ),
    );
  }

  Widget _buildExperienceTab() {
    return SingleChildScrollView(
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
                  child: const Icon(Icons.work, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengalaman Kerja',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${experienceList.length} pengalaman kerja',
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

          // Daftar pengalaman
          ...List.generate(
            experienceList.length,
            (index) => _buildExperienceCard(experienceList[index], index),
          ),

          // Button tambah pengalaman
          _buildAddExperienceButton(),
        ],
      ),
    );
  }

  Widget _buildEducationCard(Education education, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editEducation(index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: Color(0xFF007AFF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Education Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      education.institution,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${education.degree} - ${education.field}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          education.period,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (education.grade != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.grade, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            'IPK: ${education.grade}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editEducation(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceCard(Experience experience, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editExperience(index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF5856D6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.work_outline,
                  color: Color(0xFF5856D6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Experience Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.company,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience.position,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          experience.period,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    if (experience.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        experience.description!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editExperience(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddEducationButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      child: ElevatedButton.icon(
        onPressed: _addEducation,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Riwayat Pendidikan',
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

  Widget _buildAddExperienceButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      child: ElevatedButton.icon(
        onPressed: _addExperience,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Pengalaman Kerja',
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
