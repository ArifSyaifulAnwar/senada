// education_experience_screen.dart — data asli dari backend (sebelumnya
// hardcode/mock, sama seperti kasus Kontak Darurat & Informasi Keluarga)
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/addeducatioscreen.dart';
import 'package:absensikaryawan/Services/education_experience_service.dart';
import 'package:absensikaryawan/Services/teguran_service.dart';
import 'package:absensikaryawan/Screen%20HRD/Home/education_experience_hrd_screen.dart';
import 'package:flutter/material.dart';

class EducationExperienceScreen extends StatefulWidget {
  final String userId;

  const EducationExperienceScreen({super.key, required this.userId});

  @override
  State<EducationExperienceScreen> createState() =>
      _EducationExperienceScreenState();
}

class _EducationExperienceScreenState
    extends State<EducationExperienceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EducationExperienceService _service = EducationExperienceService();

  List<Education> educationList = [];
  List<Experience> experienceList = [];
  bool _isLoadingEducation = true;
  bool _isLoadingExperience = true;
  String? _educationError;
  String? _experienceError;
  bool _isHeadHrd = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEducations();
    _loadExperiences();
    _checkHeadHrd();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkHeadHrd() async {
    final result = await TeguranService.checkIsHead(widget.userId);
    if (mounted) setState(() => _isHeadHrd = result.isHrdHead);
  }

  Future<void> _loadEducations() async {
    setState(() {
      _isLoadingEducation = true;
      _educationError = null;
    });

    final res = await _service.getEducations(widget.userId);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        educationList = res.data!;
        _isLoadingEducation = false;
      });
    } else {
      setState(() {
        _educationError = res.message;
        _isLoadingEducation = false;
      });
    }
  }

  Future<void> _loadExperiences() async {
    setState(() {
      _isLoadingExperience = true;
      _experienceError = null;
    });

    final res = await _service.getExperiences(widget.userId);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        experienceList = res.data!;
        _isLoadingExperience = false;
      });
    } else {
      setState(() {
        _experienceError = res.message;
        _isLoadingExperience = false;
      });
    }
  }

  void _addEducation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEducationExperienceScreen(
          userId: widget.userId,
          type: 'education',
        ),
      ),
    );
    if (result == true) _loadEducations();
  }

  void _addExperience() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEducationExperienceScreen(
          userId: widget.userId,
          type: 'experience',
        ),
      ),
    );
    if (result == true) _loadExperiences();
  }

  void _editEducation(Education education) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEducationExperienceScreen(
          userId: widget.userId,
          type: 'education',
          educationToEdit: education,
        ),
      ),
    );
    if (result == true) _loadEducations();
  }

  void _editExperience(Experience experience) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEducationExperienceScreen(
          userId: widget.userId,
          type: 'experience',
          experienceToEdit: experience,
        ),
      ),
    );
    if (result == true) _loadExperiences();
  }

  void _deleteEducation(Education education) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Hapus Riwayat Pendidikan'),
          ],
        ),
        content: Text('Hapus riwayat pendidikan di ${education.institution}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await _service.deleteEducation(education.id, widget.userId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.success ? Colors.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              if (res.success) _loadEducations();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _deleteExperience(Experience experience) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Hapus Pengalaman Kerja'),
          ],
        ),
        content: Text('Hapus pengalaman kerja di ${experience.company}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await _service.deleteExperience(experience.id, widget.userId);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.success ? Colors.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              if (res.success) _loadExperiences();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
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
              _loadEducations();
              _loadExperiences();
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
            _buildEducationTab(),
            _buildExperienceTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadHrdButton(String label, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.groups_outlined, color: Color(0xFFEF4444)),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFFEF4444)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildEducationTab() {
    if (_isLoadingEducation) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_educationError != null) {
      return _buildErrorWidget(_educationError!, _loadEducations);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  child: const Icon(Icons.school, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riwayat Pendidikan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${educationList.length} riwayat pendidikan',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_isHeadHrd)
            _buildHeadHrdButton(
              'Lihat Pendidikan & Pengalaman Semua Karyawan',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EducationExperienceHrdScreen(hrdUserId: widget.userId),
                ),
              ),
            ),

          if (educationList.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tambahkan riwayat pendidikan Anda',
                      style: TextStyle(fontSize: 14, color: Colors.blue[800], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            ...educationList.map((e) => _buildEducationCard(e)),

          _buildAddButton('Tambah Riwayat Pendidikan', _addEducation),
        ],
      ),
    );
  }

  Widget _buildExperienceTab() {
    if (_isLoadingExperience) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_experienceError != null) {
      return _buildErrorWidget(_experienceError!, _loadExperiences);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${experienceList.length} pengalaman kerja',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_isHeadHrd)
            _buildHeadHrdButton(
              'Lihat Pendidikan & Pengalaman Semua Karyawan',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EducationExperienceHrdScreen(hrdUserId: widget.userId),
                ),
              ),
            ),

          if (experienceList.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tambahkan pengalaman kerja Anda',
                      style: TextStyle(fontSize: 14, color: Colors.blue[800], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            ...experienceList.map((e) => _buildExperienceCard(e)),

          _buildAddButton('Tambah Pengalaman Kerja', _addExperience),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationCard(Education education) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editEducation(education),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school_outlined, color: Color(0xFF007AFF), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      education.institution,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${education.degree} - ${education.field}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          education.period,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        if (education.grade != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.grade, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            'IPK: ${education.grade}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _editEducation(education);
                  if (value == 'delete') _deleteEducation(education);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [Icon(Icons.edit, size: 16, color: Colors.blue), SizedBox(width: 8), Text('Edit')]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Hapus')]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceCard(Experience experience) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editExperience(experience),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF5856D6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work_outline, color: Color(0xFF5856D6), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.company,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience.position,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          experience.period,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    if (experience.description != null && experience.description!.isNotEmpty) ...[
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
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _editExperience(experience);
                  if (value == 'delete') _deleteExperience(experience);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [Icon(Icons.edit, size: 16, color: Colors.blue), SizedBox(width: 8), Text('Edit')]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Hapus')]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF007AFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
