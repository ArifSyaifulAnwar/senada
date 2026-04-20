// pages/edit_notification_page.dart

// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/model/admin_notification_models.dart';
import 'package:flutter/material.dart';

class EditNotificationPage extends StatefulWidget {
  final AdminNotification notification;
  final VoidCallback? onUpdated;

  const EditNotificationPage({
    super.key,
    required this.notification,
    this.onUpdated,
  });

  @override
  _EditNotificationPageState createState() => _EditNotificationPageState();
}

class _EditNotificationPageState extends State<EditNotificationPage> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;

  // Form data
  late bool _isImportant;

  // Loading states
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    _titleController = TextEditingController(text: widget.notification.title);
    _messageController = TextEditingController(
      text: widget.notification.message,
    );
    _isImportant = widget.notification.isImportant;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _updateNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // For simplicity, we'll just show a success message
      // In a real implementation, you would call the update API
      await Future.delayed(Duration(seconds: 1)); // Simulate API call

      _showSuccessSnackBar('Notifikasi berhasil diperbarui');
      widget.onUpdated?.call();
      Navigator.of(context).pop();
    } catch (e) {
      _showErrorSnackBar('Gagal memperbarui notifikasi: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
          ],
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Penerima', widget.notification.userName),
            _buildInfoRow(
              'Departemen',
              widget.notification.department ?? 'Tidak ada',
            ),
            _buildInfoRow(
              'No. Karyawan',
              widget.notification.employeeNumber ?? 'Tidak ada',
            ),
            _buildInfoRow('Dibuat', widget.notification.timeAgo),
            _buildInfoRow(
              'Status',
              widget.notification.isRead ? 'Sudah dibaca' : 'Belum dibaca',
            ),
            if (widget.notification.hasPdfAttachment)
              _buildInfoRow(
                'PDF Attachment',
                widget.notification.pdfFileName ?? 'Ada',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF1E293B)),
            ),
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
        title: const Text(
          'Edit Notifikasi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              _buildInfoCard(),

              const SizedBox(height: 20),

              // Edit Form
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Notifikasi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildFormField(
                        label: 'Judul',
                        isRequired: true,
                        child: TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Masukkan judul notifikasi',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Judul harus diisi';
                            }
                            return null;
                          },
                        ),
                      ),

                      _buildFormField(
                        label: 'Pesan',
                        isRequired: true,
                        child: TextFormField(
                          controller: _messageController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Masukkan pesan notifikasi',
                            contentPadding: EdgeInsets.all(12),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Pesan harus diisi';
                            }
                            return null;
                          },
                        ),
                      ),

                      // Important Toggle
                      Row(
                        children: [
                          Switch(
                            value: _isImportant,
                            onChanged: (value) {
                              setState(() {
                                _isImportant = value;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Notifikasi Penting',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Menyimpan...'),
                              ],
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
