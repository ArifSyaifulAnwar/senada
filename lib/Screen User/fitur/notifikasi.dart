// HalamanNotifikasi.dart - Updated with API Integration
// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:absensikaryawan/models/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:absensikaryawan/Services/notification_service.dart';

class HalamanNotifikasi extends StatefulWidget {
  const HalamanNotifikasi({super.key});

  @override
  _HalamanNotifikasiState createState() => _HalamanNotifikasiState();
}

class _HalamanNotifikasiState extends State<HalamanNotifikasi>
    with TickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();

  bool _showUnreadOnly = false;
  String _selectedFilter = 'Semua';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  List<NotificationItem> _notifications = [];
  List<NotificationCategory> _categories = [];
  NotificationStats? _stats;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      // Load categories first
      await _loadCategories();
      // Then load notifications
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

  Future<void> _loadCategories() async {
    try {
      final categories = await _notificationService.getNotificationCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      // Use default categories if API fails
      _categories = [];
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
    }

    try {
      final typeFilter = _selectedFilter == 'Semua'
          ? null
          : _getTypeFromDisplayName(_selectedFilter);

      final response = await _notificationService.getUserNotifications(
        page: _currentPage,
        pageSize: _pageSize,
        typeFilter: typeFilter,
        unreadOnly: _showUnreadOnly,
      );

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

  String? _getTypeFromDisplayName(String displayName) {
    for (var category in _categories) {
      if (category.displayName == displayName) {
        return category.name == 'Semua' ? null : category.name;
      }
    }
    return null;
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications(refresh: true);
    _showSuccessSnackBar('Notifikasi berhasil diperbarui');
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      final success = await _notificationService.markAsRead(
        notificationId: notificationId,
      );

      if (success) {
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n.id == notificationId,
          );
          if (index != -1) {
            _notifications[index] = NotificationItem(
              id: _notifications[index].id,
              userId: _notifications[index].userId,
              title: _notifications[index].title,
              message: _notifications[index].message,
              type: _notifications[index].type,
              typeDisplay: _notifications[index].typeDisplay,
              iconName: _notifications[index].iconName,
              colorCode: _notifications[index].colorCode,
              referenceId: _notifications[index].referenceId,
              referenceType: _notifications[index].referenceType,
              isRead: true,
              isImportant: _notifications[index].isImportant,
              actionText: _notifications[index].actionText,
              actionUrl: _notifications[index].actionUrl,
              createdAt: _notifications[index].createdAt,
              readAt: DateTime.now(),
              expiresAt: _notifications[index].expiresAt,
            );
          }
        });

        // Refresh stats
        _updateStats();
      }
    } catch (e) {
      _showErrorSnackBar('Gagal menandai notifikasi sebagai dibaca');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await _notificationService.markAsRead(markAll: true);

      if (success) {
        setState(() {
          _notifications = _notifications.map((notification) {
            return NotificationItem(
              id: notification.id,
              userId: notification.userId,
              title: notification.title,
              message: notification.message,
              type: notification.type,
              typeDisplay: notification.typeDisplay,
              iconName: notification.iconName,
              colorCode: notification.colorCode,
              referenceId: notification.referenceId,
              referenceType: notification.referenceType,
              isRead: true,
              isImportant: notification.isImportant,
              actionText: notification.actionText,
              actionUrl: notification.actionUrl,
              createdAt: notification.createdAt,
              readAt: DateTime.now(),
              expiresAt: notification.expiresAt,
            );
          }).toList();
        });

        _updateStats();
        _showSuccessSnackBar('Semua notifikasi telah ditandai sebagai dibaca');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal menandai semua notifikasi sebagai dibaca');
    }
  }

  Future<void> _updateStats() async {
    try {
      final stats = await _notificationService.getNotificationStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui statistik notifikasi.'),
          ),
        );
      }
    }
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

  Widget _buildNotificationCard(NotificationItem notification) {
    final color = _getNotificationColor(notification.type);
    final icon = _getNotificationIcon(notification.type);
    final category = notification.typeDisplay ?? notification.type;

    return Card(
      margin: EdgeInsets.only(bottom: _getResponsivePadding(context, 12)),
      elevation: notification.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _markAsRead(notification.id),
        child: Container(
          padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: notification.isImportant
                ? Border.all(color: Colors.red, width: 1)
                : null,
            color: notification.isRead ? Colors.white : color.withOpacity(0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  SizedBox(width: _getResponsivePadding(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(context, 10),
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                            if (notification.isImportant) ...[
                              SizedBox(width: 8),
                              Icon(
                                Icons.priority_high,
                                color: Colors.red,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          notification.timeAgo,
                          style: TextStyle(
                            fontSize: _getResponsiveFontSize(context, 11),
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),

              SizedBox(height: _getResponsivePadding(context, 12)),

              // Title
              Text(
                notification.title,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 16),
                  fontWeight: notification.isRead
                      ? FontWeight.w500
                      : FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),

              SizedBox(height: _getResponsivePadding(context, 8)),

              // Message
              Text(
                notification.message,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 14),
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),

              // Action Button
              if (notification.actionText != null) ...[
                SizedBox(height: _getResponsivePadding(context, 12)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _handleNotificationAction(notification),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      backgroundColor: color.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      notification.actionText!,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationAction(NotificationItem notification) {
    // Handle different action types based on notification type
    if (notification.referenceType == 'reimbursement' &&
        notification.referenceId != null) {
      // Navigate to reimbursement detail
      _showInfoSnackBar('Membuka detail reimbursement...');
      // Navigator.pushNamed(context, '/reimbursement/detail/${notification.referenceId}');
    } else if (notification.actionUrl != null) {
      // Handle other URL actions
      _showInfoSnackBar('Membuka ${notification.actionText}...');
    } else {
      // Default action
      _showInfoSnackBar(notification.actionText ?? 'Action');
    }
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

  Widget _buildFilterChips() {
    final filterOptions = _categories.map((cat) => cat.displayName).toList();

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: _getResponsivePadding(context, 20),
        ),
        itemCount: filterOptions.length,
        itemBuilder: (context, index) {
          final filter = filterOptions[index];
          final isSelected = _selectedFilter == filter;

          return Container(
            margin: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter,
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, 12),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
                _loadNotifications(refresh: true);
              },
              backgroundColor: Colors.grey[100],
              selectedColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
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
            SizedBox(height: 16),
            Text(
              _showUnreadOnly
                  ? 'Tidak Ada Notifikasi Baru'
                  : 'Belum Ada Notifikasi',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _showUnreadOnly
                  ? 'Semua notifikasi sudah dibaca'
                  : 'Notifikasi akan muncul di sini',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.grey[500],
              ),
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
            SizedBox(height: 16),
            Text(
              'Gagal Memuat Notifikasi',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan tidak terduga',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeData,
              icon: Icon(Icons.refresh),
              label: Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Memuat notifikasi...',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.grey[600],
              ),
            ),
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
            // Loading indicator for pagination
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildNotificationCard(_notifications[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _stats?.unreadCount ?? 0;
    final totalCount = _stats?.totalNotifications ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
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
          if (unreadCount > 0)
            IconButton(
              icon: Icon(Icons.mark_email_read, color: Colors.black),
              onPressed: _markAllAsRead,
              tooltip: 'Tandai semua sebagai dibaca',
            ),
          IconButton(
            icon: Icon(
              _showUnreadOnly
                  ? Icons.mark_email_unread
                  : Icons.mark_email_read_outlined,
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
              });
              _loadNotifications(refresh: true);
            },
            tooltip: _showUnreadOnly
                ? 'Tampilkan semua'
                : 'Tampilkan belum dibaca saja',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Bar
          Container(
            padding: EdgeInsets.all(_getResponsivePadding(context, 20)),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: const Color(0xFF3B82F6),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Notifikasi',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 12),
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '$totalCount',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 18),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(_getResponsivePadding(context, 16)),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mark_email_unread,
                          color: Colors.orange,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Belum Dibaca',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 12),
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '$unreadCount',
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 18),
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          _buildFilterChips(),

          // Notification List
          Expanded(child: _buildNotificationList()),
        ],
      ),
    );
  }
}
