// Screen HRD/Home/education_experience_hrd_screen.dart
// Khusus Head HRD — kelola pendidikan & pengalaman kerja SEMUA karyawan aktif
// di perusahaannya (tambah/edit/hapus per karyawan, bukan cuma lihat).
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:absensikaryawan/Services/education_experience_service.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/addeducatioscreen.dart';

class EducationExperienceHrdScreen extends StatefulWidget {
  final String hrdUserId;

  const EducationExperienceHrdScreen({super.key, required this.hrdUserId});

  @override
  _EducationExperienceHrdScreenState createState() =>
      _EducationExperienceHrdScreenState();
}

class _EducationExperienceHrdScreenState
    extends State<EducationExperienceHrdScreen> {
  final EducationExperienceService _service = EducationExperienceService();
  final TextEditingController _searchController = TextEditingController();

  List<EmployeeEducationExperienceGroup> _groups = [];
  List<EmployeeEducationExperienceGroup> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _service.getAllForHrd(widget.hrdUserId);

    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _groups = res.data!;
        _applyFilter();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.message;
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _groups
          : _groups
                .where(
                  (g) =>
                      g.employeeName.toLowerCase().contains(q) ||
                      (g.department ?? '').toLowerCase().contains(q),
                )
                .toList();
    });
  }

  void _addEducation(EmployeeEducationExperienceGroup group) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEducationExperienceScreen(
          userId: group.userId,
          type: 'education',
          actorUserId: widget.hrdUserId,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _addExperience(EmployeeEducationExperienceGroup group) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEducationExperienceScreen(
          userId: group.userId,
          type: 'experience',
          actorUserId: widget.hrdUserId,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _editEducation(EmployeeEducationExperienceGroup group, Education e) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEducationExperienceScreen(
          userId: group.userId,
          type: 'education',
          educationToEdit: e,
          actorUserId: widget.hrdUserId,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _editExperience(EmployeeEducationExperienceGroup group, Experience e) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEducationExperienceScreen(
          userId: group.userId,
          type: 'experience',
          experienceToEdit: e,
          actorUserId: widget.hrdUserId,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _deleteEducation(Education e) {
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
        content: Text('Hapus riwayat pendidikan di ${e.institution}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await _service.deleteEducation(
                e.id,
                e.userId,
                actorUserId: widget.hrdUserId,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.success ? Colors.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              if (res.success) _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _deleteExperience(Experience e) {
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
        content: Text('Hapus pengalaman kerja di ${e.company}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await _service.deleteExperience(
                e.id,
                e.userId,
                actorUserId: widget.hrdUserId,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.success ? Colors.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              if (res.success) _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeEducationExperienceGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF007AFF).withOpacity(0.1),
            child: Text(
              group.employeeName.isNotEmpty
                  ? group.employeeName
                        .split(' ')
                        .map((n) => n.isNotEmpty ? n[0] : '')
                        .take(2)
                        .join()
                  : '-',
              style: const TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            group.employeeName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Text(
            [
              if (group.department != null && group.department!.isNotEmpty)
                group.department,
              '${group.educations.length} pendidikan, ${group.experiences.length} pengalaman',
            ].join(' • '),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF007AFF)),
            tooltip: 'Tambah data',
            onSelected: (value) {
              if (value == 'education') _addEducation(group);
              if (value == 'experience') _addExperience(group);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'education',
                child: Row(children: [Icon(Icons.school, size: 16, color: Color(0xFF007AFF)), SizedBox(width: 8), Text('Tambah Pendidikan')]),
              ),
              const PopupMenuItem(
                value: 'experience',
                child: Row(children: [Icon(Icons.work, size: 16, color: Color(0xFF5856D6)), SizedBox(width: 8), Text('Tambah Pengalaman')]),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            if (group.educations.isEmpty && group.experiences.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Belum ada data pendidikan maupun pengalaman',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            if (group.educations.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PENDIDIKAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...group.educations.map((e) => _buildEducationTile(group, e)),
              const SizedBox(height: 8),
            ],
            if (group.experiences.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PENGALAMAN KERJA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5856D6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...group.experiences.map((e) => _buildExperienceTile(group, e)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEducationTile(EmployeeEducationExperienceGroup group, Education e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.institution, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'edit') _editEducation(group, e);
                  if (value == 'delete') _deleteEducation(e);
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
          const SizedBox(height: 2),
          Text(
            '${e.degree} - ${e.field}',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(e.period, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              if (e.grade != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.grade, size: 13, color: Colors.amber[600]),
                const SizedBox(width: 4),
                Text(
                  'IPK: ${e.grade}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceTile(EmployeeEducationExperienceGroup group, Experience e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.company, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'edit') _editExperience(group, e);
                  if (value == 'delete') _deleteExperience(e);
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
          const SizedBox(height: 2),
          Text(e.position, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(e.period, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          if (e.description != null && e.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              e.description!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Pendidikan & Pengalaman Karyawan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama karyawan / departemen...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 56,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 56,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _groups.isEmpty
                                ? 'Belum ada karyawan aktif'
                                : 'Tidak ditemukan',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) =>
                            _buildEmployeeCard(_filtered[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
