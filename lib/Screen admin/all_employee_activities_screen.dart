// Screen User/fitur/all_employee_activities_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:absensikaryawan/Screen%20admin/service/web_preview.dart';
import 'package:absensikaryawan/Services/web_download.dart';

import '../models/dailyactivitymodels.dart';
import 'service/daily_activity_service.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class AllEmployeeActivitiesScreen extends StatefulWidget {
  const AllEmployeeActivitiesScreen({super.key});

  @override
  State<AllEmployeeActivitiesScreen> createState() =>
      _AllEmployeeActivitiesScreenState();
}

class _AllEmployeeActivitiesScreenState
    extends State<AllEmployeeActivitiesScreen> {
  bool _isLoading = true;
  bool _accessDenied = false;
  String? _accessMessage;
  bool _isAttachmentProcessing = false;

  List<DailyActivityHRDItem> _activities = [];
  String _searchQuery = '';
  String _categoryFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _accessDenied = false;
    });

    final result = await DailyActivityService.getAllActivitiesHRD();
    if (!mounted) return;

    setState(() {
      _accessDenied = result['accessDenied'] ?? false;
      _accessMessage = result['message'];
      _activities = List<DailyActivityHRDItem>.from(result['activities'] ?? []);
      _isLoading = false;
    });
  }

  List<DailyActivityHRDItem> get _filteredActivities {
    return _activities.where((a) {
      final q = _searchQuery.toLowerCase();
      final matchSearch =
          q.isEmpty ||
          a.employeeName.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          a.categoryLabel.toLowerCase().contains(q);
      final matchCategory =
          _categoryFilter == 'Semua' || a.categoryLabel == _categoryFilter;
      return matchSearch && matchCategory;
    }).toList();
  }

  List<String> get _categoryOptions {
    final set = <String>{'Semua'};
    for (final a in _activities) {
      if (a.categoryLabel.isNotEmpty) set.add(a.categoryLabel);
    }
    return set.toList();
  }

  String _formatDate(DateTime d) =>
      DateFormat('dd MMM yyyy', 'id_ID').format(d);

  IconData _fileIcon(String fileType) {
    if (fileType.startsWith('image/')) return Icons.image_rounded;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (fileType.contains('word')) return Icons.description_rounded;
    if (fileType.contains('excel')) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Aktivitas Karyawan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accessDenied
          ? _buildAccessDenied()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _isWideScreen(context)
                  ? _buildWebBody()
                  : _buildMobileBody(),
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _accessMessage ?? 'Anda tidak memiliki akses ke fitur ini',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildFilters()),
        if (_filteredActivities.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildActivityCard(_filteredActivities[i]),
                childCount: _filteredActivities.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _buildFilters(),
              ),
            ),
          ),
        ),
        if (_filteredActivities.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: _filteredActivities
                        .map((a) => _buildActivityCard(a))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan / deskripsi / kategori...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categoryOptions.map((c) {
                final sel = c == _categoryFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (_) => setState(() => _categoryFilter = c),
                    selectedColor: const Color(0xFF007AFF),
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              'Belum ada aktivitas',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(DailyActivityHRDItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showDetail(item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        item.icon,
                        size: 16,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.employeeName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            '${item.categoryLabel} • ${_formatDate(item.activityDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF374151),
                  ),
                ),
                if (item.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.attachments.length} lampiran',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(DailyActivityHRDItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(
                              0xFF007AFF,
                            ).withOpacity(0.1),
                            child: Text(
                              item.employeeName.isNotEmpty
                                  ? item.employeeName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFF007AFF),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.employeeName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  item.jobPosition,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(bottomContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _detailSection(
                        title: 'Detail Aktivitas',
                        icon: Icons.event_note_rounded,
                        children: [
                          _detailRow('Kategori', item.categoryLabel),
                          _detailRow('Tanggal', _formatDate(item.activityDate)),
                          if (item.startTime != null && item.endTime != null)
                            _detailRow(
                              'Jam Kerja',
                              '${item.startTime!.formatted} - ${item.endTime!.formatted}',
                            ),
                          if (item.displayLocation.isNotEmpty)
                            _detailRow('Lokasi', item.displayLocation),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _detailSection(
                        title: 'Deskripsi',
                        icon: Icons.notes_rounded,
                        children: [
                          Text(
                            item.description,
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ],
                      ),
                      if (item.attachments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildAttachmentSection(item),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF007AFF), size: 17),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentSection(DailyActivityHRDItem item) {
    return _detailSection(
      title: item.attachments.length > 1
          ? 'Lampiran (${item.attachments.length} file)'
          : 'Lampiran',
      icon: Icons.attach_file_rounded,
      children: List.generate(item.attachments.length, (i) {
        final att = item.attachments[i];
        return Padding(
          padding: EdgeInsets.only(
            bottom: i < item.attachments.length - 1 ? 12 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _fileIcon(att.fileType),
                        color: const Color(0xFF007AFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        att.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAttachmentProcessing
                          ? null
                          : () => _handleAttachment(att, preview: true),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF007AFF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isAttachmentProcessing
                          ? null
                          : () => _handleAttachment(att, preview: false),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _handleAttachment(
    DailyActivityAttachment att, {
    required bool preview,
  }) async {
    if (att.id == null || _isAttachmentProcessing) return;
    setState(() => _isAttachmentProcessing = true);
    try {
      final bytes = await DailyActivityService.downloadAttachmentBytesHRD(
        att.id!,
      );
      if (bytes == null) {
        _showSnack('Gagal mengambil file.', Colors.red);
        return;
      }
      if (preview) {
        await _previewAttachment(bytes, att.fileName, att.fileType);
      } else {
        await _downloadAttachment(bytes, att.fileName);
      }
    } finally {
      if (mounted) setState(() => _isAttachmentProcessing = false);
    }
  }

  Future<void> _previewAttachment(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    if (mimeType.startsWith('image/')) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      );
      return;
    }
    if (kIsWeb) {
      openBytesInBrowser(bytes, fileName, mimeType);
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final localFile = File('${tempDir.path}/${_safeFileName(fileName)}');
    await localFile.writeAsBytes(bytes, flush: true);
    await OpenFile.open(localFile.path);
  }

  Future<void> _downloadAttachment(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName);
      _showSnack('File sedang diunduh.', Colors.green);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/${_safeFileName(fileName)}');
    await localFile.writeAsBytes(bytes, flush: true);
    _showSnack('File tersimpan: ${localFile.path}', Colors.green);
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.trim().isEmpty ? 'lampiran' : sanitized;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
