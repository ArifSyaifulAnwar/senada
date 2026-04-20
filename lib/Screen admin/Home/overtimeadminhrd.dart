// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/Services/overtimeservice.dart';
import 'package:flutter/material.dart';

class OvertimeApprovalScreen extends StatefulWidget {
  const OvertimeApprovalScreen({super.key});

  @override
  State<OvertimeApprovalScreen> createState() => _OvertimeApprovalScreenState();
}

class _OvertimeApprovalScreenState extends State<OvertimeApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OvertimeService _overtimeService = OvertimeService();

  List<Overtime> _pendingList = [];
  List<Overtime> _approvedList = [];
  List<Overtime> _rejectedList = [];

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load pending requests
      final pendingResponse = await _overtimeService.getAllOvertime(
        status: 'Pending',
        pageSize: 50,
      );

      // Load approved requests
      final approvedResponse = await _overtimeService.getAllOvertime(
        status: 'Approved',
        pageSize: 50,
      );

      // Load rejected requests
      final rejectedResponse = await _overtimeService.getAllOvertime(
        status: 'Rejected',
        pageSize: 50,
      );

      if (pendingResponse.success &&
          approvedResponse.success &&
          rejectedResponse.success) {
        setState(() {
          _pendingList = pendingResponse.data?.data ?? [];
          _approvedList = approvedResponse.data?.data ?? [];
          _rejectedList = rejectedResponse.data?.data ?? [];
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Gagal memuat data';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveOvertime(Overtime overtime) async {
    try {
      final response = await _overtimeService.approveOvertime(
        id: overtime.id,
        status: 'Approved',
      );

      if (response.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
        _loadAllData();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyetujui: $e')));
    }
  }

  Future<void> _rejectOvertime(Overtime overtime) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pengajuan Lembur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Apakah Anda yakin ingin menolak pengajuan lembur dari ${overtime.userName}?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan',
                hintText: 'Masukkan alasan penolakan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await _overtimeService.approveOvertime(
          id: overtime.id,
          status: 'Rejected',
          rejectionReason: reasonController.text.trim(),
        );

        if (response.success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(response.message)));
          _loadAllData();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(response.message)));
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menolak: $e')));
      }
    }
  }

  void _showOvertimeDetail(Overtime overtime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Lembur - ${overtime.userName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Tanggal', overtime.formattedDate),
              _buildDetailRow('Jam Mulai', overtime.formattedMulai),
              _buildDetailRow('Jam Selesai', overtime.formattedSelesai),
              _buildDetailRow(
                'Total Jam',
                '${overtime.totalJam.toStringAsFixed(1)} jam',
              ),
              _buildDetailRow('Status', overtime.status),
              if (overtime.catatan != null && overtime.catatan!.isNotEmpty)
                _buildDetailRow('Catatan', overtime.catatan!),
              if (overtime.rejectionReason != null &&
                  overtime.rejectionReason!.isNotEmpty)
                _buildDetailRow('Alasan Ditolak', overtime.rejectionReason!),
              if (overtime.approverName != null)
                _buildDetailRow('Disetujui oleh', overtime.approverName!),
              if (overtime.approvedAt != null)
                _buildDetailRow(
                  'Tanggal Approve',
                  '${overtime.approvedAt!.day}/${overtime.approvedAt!.month}/${overtime.approvedAt!.year}',
                ),
              _buildDetailRow(
                'Tanggal Pengajuan',
                '${overtime.createdAt.day}/${overtime.createdAt.month}/${overtime.createdAt.year}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "pending":
      default:
        return Colors.orange;
    }
  }

  IconData _iconForStatus(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Icons.check_circle;
      case "rejected":
        return Icons.cancel;
      case "pending":
      default:
        return Icons.hourglass_empty;
    }
  }

  Widget _buildOvertimeCard(Overtime overtime, {bool showActions = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _colorForStatus(
                    overtime.status,
                  ).withOpacity(0.1),
                  child: Text(
                    overtime.userName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: _colorForStatus(overtime.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overtime.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        overtime.formattedDate,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colorForStatus(overtime.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconForStatus(overtime.status),
                        size: 14,
                        color: _colorForStatus(overtime.status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        overtime.status,
                        style: TextStyle(
                          color: _colorForStatus(overtime.status),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${overtime.formattedMulai} - ${overtime.formattedSelesai}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${overtime.totalJam.toStringAsFixed(1)} jam',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (overtime.catatan != null && overtime.catatan!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  overtime.catatan!,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (overtime.rejectionReason != null &&
                overtime.rejectionReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.red[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alasan: ${overtime.rejectionReason}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showOvertimeDetail(overtime),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Detail'),
                ),
                const Spacer(),
                if (showActions &&
                    overtime.status.toLowerCase() == 'pending') ...[
                  TextButton.icon(
                    onPressed: () => _rejectOvertime(overtime),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Tolak'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approveOvertime(overtime),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Setujui'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
    List<Overtime> overtimeList, {
    bool showActions = false,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (overtimeList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tidak ada data'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: overtimeList.length,
        itemBuilder: (context, index) {
          return _buildOvertimeCard(
            overtimeList[index],
            showActions: showActions,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Lembur'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Pending (${_pendingList.length})',
              icon: const Icon(Icons.hourglass_empty),
            ),
            Tab(
              text: 'Disetujui (${_approvedList.length})',
              icon: const Icon(Icons.check_circle),
            ),
            Tab(
              text: 'Ditolak (${_rejectedList.length})',
              icon: const Icon(Icons.cancel),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(_pendingList, showActions: true),
          _buildTabContent(_approvedList),
          _buildTabContent(_rejectedList),
        ],
      ),
    );
  }
}
