// pages/admin_notification_page.dart

// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/Screen%20admin/Home/create_notification_page.dart';
import 'package:absensikaryawan/Screen%20admin/Home/edit_notification_page.dart';
import 'package:absensikaryawan/Screen%20admin/model/admin_notification_models.dart';
import 'package:absensikaryawan/Screen%20admin/service/admin_notification_service.dart';
import 'package:flutter/material.dart';

class HalamanNotifikasiAdmin extends StatefulWidget {
  const HalamanNotifikasiAdmin({super.key});

  @override
  _HalamanNotifikasiAdminState createState() => _HalamanNotifikasiAdminState();
}

class _HalamanNotifikasiAdminState extends State<HalamanNotifikasiAdmin>
    with TickerProviderStateMixin {
  final AdminNotificationService _notificationService =
      AdminNotificationService();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  List<AdminNotification> _notifications = [];
  List<NotificationTypeOption> _notificationTypes = [];
  AdminNotificationStats? _stats;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;

  String _selectedFilter = 'Semua';
  bool? _selectedReadFilter;
  String? _selectedUserFilter;
  String _searchText = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadNotificationTypes();
      await _loadNotifications(refresh: true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotificationTypes() async {
    try {
      final types = await _notificationService.getNotificationTypes();
      setState(() {
        _notificationTypes = [
          NotificationTypeOption(value: 'all', display: 'Semua'),
          ...types,
        ];
      });
    } catch (e) {
      // Use default types if API fails
      _notificationTypes = [
        NotificationTypeOption(value: 'all', display: 'Semua'),
        NotificationTypeOption(value: 'info', display: 'Informasi'),
        NotificationTypeOption(value: 'warning', display: 'Peringatan'),
        NotificationTypeOption(value: 'success', display: 'Berhasil'),
        NotificationTypeOption(value: 'error', display: 'Error'),
        NotificationTypeOption(value: 'hr', display: 'HR'),
        NotificationTypeOption(value: 'leave', display: 'Cuti'),
        NotificationTypeOption(value: 'finance', display: 'Finance'),
      ];
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
    }

    try {
      final request = AdminNotificationRequest(
        page: _currentPage,
        pageSize: _pageSize,
        typeFilter: _selectedFilter == 'Semua' ? null : _selectedFilter,
        isReadFilter: _selectedReadFilter,
        userIdFilter: _selectedUserFilter,
        searchText: _searchText.isNotEmpty ? _searchText : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      final response = await _notificationService.getAllNotifications(request);

      setState(() {
        if (refresh) {
          _notifications = response.data;
        } else {
          _notifications.addAll(response.data);
        }

        _stats = response.stats;
        _hasMoreData =
            response.data.length == _pageSize &&
            _notifications.length < response.totalCount;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showErrorSnackBar(_errorMessage!);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadNotifications();

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications(refresh: true);
    _showSuccessSnackBar('Data notifikasi berhasil diperbarui');
  }

  Future<void> _deleteNotification(int id) async {
    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    try {
      final success = await _notificationService.deleteNotification(id);
      if (success) {
        await _refreshNotifications();
        _showSuccessSnackBar('Notifikasi berhasil dihapus');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal menghapus notifikasi: $e');
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Notifikasi'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus notifikasi ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  Widget _buildFilterBottomSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Notifikasi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Type Filter
              const Text('Tipe Notifikasi'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedFilter,
                items: _notificationTypes.map((type) {
                  return DropdownMenuItem(
                    value: type.value == 'all' ? 'Semua' : type.value,
                    child: Text(type.display),
                  );
                }).toList(),
                onChanged: (value) {
                  setModalState(() {
                    _selectedFilter = value ?? 'Semua';
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Read Status Filter
              const Text('Status Baca'),
              const SizedBox(height: 8),
              DropdownButtonFormField<bool?>(
                value: _selectedReadFilter,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Semua')),
                  DropdownMenuItem(value: true, child: Text('Sudah Dibaca')),
                  DropdownMenuItem(value: false, child: Text('Belum Dibaca')),
                ],
                onChanged: (value) {
                  setModalState(() {
                    _selectedReadFilter = value;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedFilter = 'Semua';
                          _selectedReadFilter = null;
                          _selectedUserFilter = null;
                          _dateFrom = null;
                          _dateTo = null;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadNotifications(refresh: true);
                      },
                      child: const Text('Terapkan'),
                    ),
                  ),
                ],
              ),

              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        );
      },
    );
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

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'security':
        return Colors.purple;
      case 'system':
        return Colors.teal;
      case 'hr':
        return Colors.indigo;
      case 'finance':
        return Colors.amber;
      case 'it':
        return Colors.cyan;
      case 'leave':
        return Colors.lightGreen;
      case 'overtime':
        return Colors.deepOrange;
      case 'reimbursement':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'success':
        return Icons.check_circle_outline;
      case 'error':
        return Icons.error_outline;
      case 'security':
        return Icons.security;
      case 'system':
        return Icons.settings;
      case 'hr':
        return Icons.people_outline;
      case 'finance':
        return Icons.account_balance;
      case 'it':
        return Icons.computer;
      case 'leave':
        return Icons.event_available;
      case 'overtime':
        return Icons.access_time;
      case 'reimbursement':
        return Icons.payments;
      default:
        return Icons.notifications;
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

  Widget _buildAdminNotificationCard(AdminNotification notification) {
    final color = _getNotificationColor(notification.type);
    final icon = _getNotificationIcon(notification.type);

    return Card(
      margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 12)),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: notification.isImportant
              ? Border.all(color: Colors.red, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              notification.typeDisplay,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 10),
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          if (notification.isImportant) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.priority_high,
                              color: Colors.red,
                              size: 16,
                            ),
                          ],
                          if (notification.hasPdfAttachment) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.red,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Untuk: ${notification.userName}',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 11),
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditNotificationPage(
                              notification: notification,
                              onUpdated: _refreshNotifications,
                            ),
                          ),
                        );
                        break;
                      case 'download':
                        if (notification.hasPdfAttachment) {
                          _downloadPdf(notification);
                        }
                        break;
                      case 'delete':
                        _deleteNotification(notification.id);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (notification.hasPdfAttachment)
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Download PDF',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              notification.title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 8),

            // Message
            Text(
              notification.message,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // PDF attachment info
            if (notification.hasPdfAttachment) ...[
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Surat Edaran PDF',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${notification.pdfFileName} (${notification.formattedFileSize})',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 11),
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _downloadPdf(notification),
                      icon: const Icon(Icons.download),
                      color: Colors.red[600],
                      tooltip: 'Download PDF',
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Footer info
            Row(
              children: [
                Icon(
                  notification.isRead
                      ? Icons.mark_email_read
                      : Icons.mark_email_unread,
                  size: 16,
                  color: notification.isRead ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  notification.isRead ? 'Sudah dibaca' : 'Belum dibaca',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    color: notification.isRead ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  notification.timeAgo,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _downloadPdf(AdminNotification notification) async {
    try {
      if (!notification.hasPdfAttachment) {
        _showErrorSnackBar('Tidak ada file PDF yang dilampirkan');
        return;
      }

      _showInfoSnackBar('Mengunduh file PDF...');

      final file = await _notificationService.downloadNotificationPdf(
        notification.id,
        notification.pdfFileName!,
      );

      _showSuccessSnackBar('File berhasil diunduh: ${file.path}');
    } catch (e) {
      _showErrorSnackBar('Gagal mengunduh file: $e');
    }
  }

  Widget _buildStatsCards() {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Notifikasi',
                  _stats!.totalNotifications.toString(),
                  Icons.notifications,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Belum Dibaca',
                  _stats!.unreadCount.toString(),
                  Icons.mark_email_unread,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Hari Ini',
                  _stats!.todayCount.toString(),
                  Icons.today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Penting',
                  _stats!.importantCount.toString(),
                  Icons.priority_high,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 12),
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari notifikasi...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (value) {
                setState(() {
                  _searchText = value;
                });
                _loadNotifications(refresh: true);
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_getResponsivePadding(context, 40)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Notifikasi',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat notifikasi pertama Anda',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateNotificationPage(
                      onCreated: _refreshNotifications,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Buat Notifikasi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_getResponsivePadding(context, 40)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan tidak terduga',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat data notifikasi...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildAdminNotificationCard(_notifications[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Kelola Notifikasi',
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
          IconButton(
            onPressed: _refreshNotifications,
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCards(),
          _buildSearchBar(),
          Expanded(child: _buildNotificationList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CreateNotificationPage(onCreated: _refreshNotifications),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Buat Notifikasi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
