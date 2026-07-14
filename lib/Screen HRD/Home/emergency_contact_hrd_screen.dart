// Screen HRD/Home/emergency_contact_hrd_screen.dart
// Khusus Head HRD — kelola kontak darurat SEMUA karyawan aktif di
// perusahaannya (tambah/edit/hapus per karyawan, bukan cuma lihat).
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:absensikaryawan/Services/emergencycontactservice.dart';
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/keamanan/addemergencycontact.dart';

class EmergencyContactHrdScreen extends StatefulWidget {
  final String hrdUserId;

  const EmergencyContactHrdScreen({super.key, required this.hrdUserId});

  @override
  _EmergencyContactHrdScreenState createState() =>
      _EmergencyContactHrdScreenState();
}

class _EmergencyContactHrdScreenState
    extends State<EmergencyContactHrdScreen> {
  final EmergencyContactService _service = EmergencyContactService();
  final TextEditingController _searchController = TextEditingController();

  List<EmployeeEmergencyContactGroup> _groups = [];
  List<EmployeeEmergencyContactGroup> _filtered = [];
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

    final res = await _service.getAllContactsForHrd(widget.hrdUserId);

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

  void _addContact(EmployeeEmergencyContactGroup group) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmergencyContactScreen(
          userId: group.userId,
          actorUserId: widget.hrdUserId,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _editContact(EmployeeEmergencyContactGroup group, EmergencyContact contact) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmergencyContactScreen(
          userId: group.userId,
          contactToEdit: contact,
          actorUserId: widget.hrdUserId,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _deleteContact(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Hapus Kontak Darurat'),
          ],
        ),
        content: Text('Hapus kontak darurat ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await _service.deleteEmergencyContact(
                contact.id,
                contact.userId,
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

  Widget _buildEmployeeCard(EmployeeEmergencyContactGroup group) {
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
              '${group.contacts.length} kontak',
            ].join(' • '),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF007AFF)),
            tooltip: 'Tambah kontak darurat',
            onPressed: () => _addContact(group),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: group.contacts.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Belum ada kontak darurat',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ),
                ]
              : group.contacts.map((c) => _buildContactTile(group, c)).toList(),
        ),
      ),
    );
  }

  Widget _buildContactTile(EmployeeEmergencyContactGroup group, EmergencyContact c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: c.isPrimary
            ? Border.all(color: const Color(0xFF007AFF), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (c.isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'UTAMA',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'edit') _editContact(group, c);
                  if (value == 'delete') _deleteContact(c);
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
            c.relationship,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF007AFF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(c.phoneNumber, style: const TextStyle(fontSize: 13)),
            ],
          ),
          if (c.email != null && c.email!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(c.email!, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
          if (c.address != null && c.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.address!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
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
          'Kontak Darurat Karyawan',
          style: TextStyle(
            fontSize: 18,
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
                            Icons.contact_emergency_outlined,
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
