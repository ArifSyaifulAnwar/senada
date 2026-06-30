// Screen User/fitur/daily_activity_screen.dart
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
import '../../Screen admin/all_employee_activities_screen.dart';
import '../../Screen admin/service/daily_activity_service.dart';
import '../../models/dailyactivitymodels.dart';
import 'add_daily_activity_screen.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class DailyActivityScreen extends StatefulWidget {
  const DailyActivityScreen({super.key});

  @override
  State<DailyActivityScreen> createState() => _DailyActivityScreenState();
}

class _DailyActivityScreenState extends State<DailyActivityScreen> {
  bool _isLoading = false;
  bool _isAttachmentProcessing = false;
  String _filterCategory = 'Semua';
  List<DailyActivityItem> _activities = [];
  bool _hasHRDAccess = false;
  Future<void> _checkHRDAccess() async {
    final result = await DailyActivityService.getAllActivitiesHRD();
    if (mounted) {
      setState(() => _hasHRDAccess = !(result['accessDenied'] ?? true));
    }
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final data = await DailyActivityService.getMyActivities();
      if (mounted) setState(() => _activities = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _checkHRDAccess();
  }

  Future<void> _openAddActivity() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddDailyActivityScreen()),
    );

    if (result == true) {
      await _loadActivities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aktivitas harian berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  List<DailyActivityItem> get _filteredActivities {
    if (_filterCategory == 'Semua') return _activities;
    return _activities
        .where((a) => a.categoryLabel == _filterCategory)
        .toList();
  }

  List<String> get _categoryFilters {
    final set = <String>{'Semua'};
    for (final a in _activities) {
      if (a.categoryLabel.isNotEmpty) set.add(a.categoryLabel);
    }
    return set.toList();
  }

  String _formatDate(DateTime d) =>
      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(d);

  IconData _fileIcon(String fileType) {
    if (fileType.startsWith('image/')) return Icons.image_rounded;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (fileType.contains('word')) return Icons.description_rounded;
    if (fileType.contains('excel')) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWideScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Aktivitas Harian',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.white,
        actions: [
          if (_hasHRDAccess)
            IconButton(
              tooltip: 'Aktivitas Karyawan',
              icon: const Icon(Icons.groups_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AllEmployeeActivitiesScreen(),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(),
      body: RefreshIndicator(
        onRefresh: _loadActivities,
        child: isWeb ? _buildWebBody() : _buildMobileBody(),
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _openAddActivity,
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Tambah Aktivitas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildFilterChips()),
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredActivities.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
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
                child: _buildFilterChips(),
              ),
            ),
          ),
        ),
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredActivities.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  child: Column(
                    children: _filteredActivities
                        .map((item) => _buildActivityCard(item))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: _categoryFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _categoryFilters[i];
          final sel = c == _filterCategory;
          return ChoiceChip(
            label: Text(c),
            selected: sel,
            onSelected: (_) => setState(() => _filterCategory = c),
            selectedColor: const Color(0xFF007AFF),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: sel ? const Color(0xFF007AFF) : Colors.grey.shade300,
            ),
            labelStyle: TextStyle(
              color: sel ? Colors.white : const Color(0xFF374151),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.today_outlined,
                      size: 48,
                      color: const Color(0xFF007AFF).withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Belum ada aktivitas harian',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tekan tombol "Tambah Aktivitas" untuk mulai mencatat\nkegiatan harian Anda beserta bukti pendukung.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey[500],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Activity Card ────────────────────────────────────────────────────────

  Widget _buildActivityCard(DailyActivityItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showDetail(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.categoryLabel,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(item.activityDate),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
                if (item.displayLocation.isNotEmpty ||
                    (item.startTime != null && item.endTime != null)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (item.displayLocation.isNotEmpty)
                        _buildMetaChip(
                          Icons.location_on_outlined,
                          item.displayLocation,
                        ),
                      if (item.startTime != null && item.endTime != null)
                        _buildMetaChip(
                          Icons.access_time_rounded,
                          '${item.startTime!.formatted} - ${item.endTime!.formatted}',
                        ),
                    ],
                  ),
                ],
                if (item.attachments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final att = item.attachments[i];
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _fileIcon(att.fileType),
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Text(
                                  att.fileName.length > 8
                                      ? '${att.fileName.substring(0, 6)}…'
                                      : att.fileName,
                                  style: const TextStyle(fontSize: 7.5),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF007AFF).withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: const Color(0xFF007AFF).withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
      ],
    );
  }

  // ── Detail Modal ──────────────────────────────────────────────────────────

  void _showDetail(DailyActivityItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.icon,
                              color: const Color(0xFF007AFF),
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              item.categoryLabel,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(bottomContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _detailSection(
                        title: 'Detail Aktivitas',
                        icon: Icons.event_note_rounded,
                        children: [
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
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      if (item.attachments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildAttachmentDetailSection(item),
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
                  color: Color(0xFF1F2937),
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
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Attachment preview/download ──────────────────────────────────────────

  Widget _buildAttachmentDetailSection(DailyActivityItem item) {
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
                        color: const Color(0xFF007AFF).withOpacity(0.10),
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
                          color: Color(0xFF1F2937),
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
                      icon: _isAttachmentProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF007AFF),
                        side: BorderSide(
                          color: const Color(0xFF007AFF).withOpacity(0.45),
                        ),
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
    if (att.id == null) {
      _showSnack('File tidak valid.', Colors.red);
      return;
    }
    if (_isAttachmentProcessing) return;

    setState(() => _isAttachmentProcessing = true);
    try {
      final bytes = await DailyActivityService.downloadAttachmentBytes(att.id!);
      if (bytes == null) {
        _showSnack('Gagal mengambil file dari server.', Colors.red);
        return;
      }

      if (preview) {
        await _previewAttachment(bytes, att.fileName, att.fileType);
      } else {
        await _downloadAttachment(bytes, att.fileName);
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
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
      await _showImagePreview(bytes, fileName);
      return;
    }

    if (kIsWeb) {
      openBytesInBrowser(bytes, fileName, mimeType);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final localFile = File('${tempDir.path}/${_safeFileName(fileName)}');
    await localFile.writeAsBytes(bytes, flush: true);

    final result = await OpenFile.open(localFile.path);
    if (result.type != ResultType.done && mounted) {
      _showSnack(
        result.message.isEmpty
            ? 'Tidak ada aplikasi untuk membuka file ini.'
            : result.message,
        Colors.red,
      );
    }
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

  Future<void> _showImagePreview(Uint8List bytes, String fileName) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF007AFF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 4,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('Gambar tidak dapat ditampilkan.'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.trim().isEmpty ? 'lampiran_aktivitas' : sanitized;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
