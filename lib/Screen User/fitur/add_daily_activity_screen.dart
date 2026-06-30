// Screen User/fitur/add_daily_activity_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../Screen admin/service/daily_activity_service.dart';
import '../../models/dailyactivitymodels.dart';

bool _isWideScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 768;

class AddDailyActivityScreen extends StatefulWidget {
  const AddDailyActivityScreen({super.key});

  @override
  State<AddDailyActivityScreen> createState() => _AddDailyActivityScreenState();
}

class _AddDailyActivityScreenState extends State<AddDailyActivityScreen> {
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<DailyActivityAttachment> _attachments = [];
  bool _isSubmitting = false;

  bool _isLoadingMasterData = true;
  List<DailyActivityCategory> _categories = [];
  List<OfficeLocation> _officeLocations = [];
  DailyActivityCategory? _selectedCategory;
  OfficeLocation? _selectedOfficeLocation;

  static const int _maxAttachments = 5;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoadingMasterData = true);
    try {
      final results = await Future.wait([
        DailyActivityService.getCategories(),
        DailyActivityService.getOfficeLocations(),
      ]);
      final categories = results[0] as List<DailyActivityCategory>;
      final locations = results[1] as List<OfficeLocation>;

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _officeLocations = locations;
        if (categories.isNotEmpty) _selectedCategory = categories.first;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMasterData = false);
    }
  }

  // ── Pickers ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF007AFF)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF007AFF)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      if (_endTime != null && _toMinutes(_endTime!) <= _toMinutes(picked)) {
        _endTime = null;
      }
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime ?? TimeOfDay.now()),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF007AFF)),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (_startTime != null && _toMinutes(picked) <= _toMinutes(_startTime!)) {
      _showSnack('Jam selesai harus setelah jam mulai', Colors.red);
      return;
    }
    setState(() => _endTime = picked);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // ── Attachments ────────────────────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    if (_attachments.length >= _maxAttachments) return _showLimitWarning();
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    setState(() {
      _attachments.add(
        DailyActivityAttachment(
          fileName: photo.name,
          fileType: 'image/jpeg',
          bytes: bytes,
        ),
      );
    });
  }

  Future<void> _pickFromGallery() async {
    final remainingSlot = _maxAttachments - _attachments.length;
    if (remainingSlot <= 0) return _showLimitWarning();
    final images = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;

    final toAdd = images.take(remainingSlot).toList();
    for (final img in toAdd) {
      final bytes = await img.readAsBytes();
      final mime = lookupMimeType(img.path) ?? 'image/jpeg';
      _attachments.add(
        DailyActivityAttachment(
          fileName: img.name,
          fileType: mime,
          bytes: bytes,
        ),
      );
    }
    setState(() {});

    if (images.length > remainingSlot && mounted) {
      _showSnack(
        'Hanya $remainingSlot foto ditambahkan (maks $_maxAttachments lampiran)',
        Colors.orange,
      );
    }
  }

  Future<void> _pickFiles() async {
    final remainingSlot = _maxAttachments - _attachments.length;
    if (remainingSlot <= 0) return _showLimitWarning();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final files = result.files.take(remainingSlot).toList();
    for (final f in files) {
      if (f.bytes == null) continue;
      final mime = lookupMimeType(f.name) ?? 'application/octet-stream';
      _attachments.add(
        DailyActivityAttachment(
          fileName: f.name,
          fileType: mime,
          bytes: f.bytes!,
        ),
      );
    }
    setState(() {});

    if (result.files.length > remainingSlot && mounted) {
      _showSnack(
        'Hanya $remainingSlot file ditambahkan (maks $_maxAttachments lampiran)',
        Colors.orange,
      );
    }
  }

  void _showLimitWarning() => _showSnack(
    'Maksimal $_maxAttachments lampiran per aktivitas',
    Colors.orange,
  );

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _removeAttachment(int index) =>
      setState(() => _attachments.removeAt(index));

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  IconData _fileIcon(String fileType) {
    if (fileType.startsWith('image/')) return Icons.image_rounded;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (fileType.contains('word')) return Icons.description_rounded;
    if (fileType.contains('excel')) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      _showSnack('Deskripsi aktivitas wajib diisi', Colors.red);
      return;
    }
    if (_selectedCategory == null) {
      _showSnack('Kategori aktivitas wajib dipilih', Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final attachmentsPayload = _attachments
          .where((a) => a.bytes != null)
          .map(
            (a) => {
              'Name': a.fileName,
              'FileType': a.fileType,
              'FileContentBase64': base64Encode(a.bytes!),
            },
          )
          .toList();

      final success = await DailyActivityService.createActivity(
        activityDate: _selectedDate,
        categoryId: _selectedCategory!.id,
        description: _descCtrl.text.trim(),
        officeLocationId: _selectedOfficeLocation?.id,
        locationText: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        startTime: _startTime == null
            ? null
            : TimeOfDayValue(_startTime!.hour, _startTime!.minute),
        endTime: _endTime == null
            ? null
            : TimeOfDayValue(_endTime!.hour, _endTime!.minute),
        attachments: attachmentsPayload,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        Navigator.pop(context, true);
      } else {
        _showSnack('Gagal menyimpan aktivitas. Coba lagi.', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack('Error: $e', Colors.red);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWideScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Tambah Aktivitas Harian',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.white,
      ),
      body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
      bottomNavigationBar: isWeb ? null : _buildBottomSubmitBar(),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: _buildFormContent(),
    );
  }

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFormContent(),
                const SizedBox(height: 24),
                SizedBox(height: 48, child: _buildSubmitButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    final isWeb = _isWideScreen(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: 'Detail Waktu',
          icon: Icons.event_note_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Tanggal Aktivitas'),
              const SizedBox(height: 8),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildFieldLabel('Jam Kerja (Opsional)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTimeField(isStart: true)),
                  SizedBox(width: isWeb ? 12 : 10),
                  Expanded(child: _buildTimeField(isStart: false)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Kategori & Lokasi',
          icon: Icons.category_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Kategori Aktivitas'),
              const SizedBox(height: 8),
              _buildCategorySelector(),
              const SizedBox(height: 16),
              _buildFieldLabel('Lokasi Kantor'),
              const SizedBox(height: 8),
              _buildLocationDropdown(),
              const SizedBox(height: 16),
              _buildFieldLabel('Catatan Lokasi Tambahan (Opsional)'),
              const SizedBox(height: 8),
              _buildLocationTextField(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Deskripsi',
          icon: Icons.notes_rounded,
          child: TextField(
            controller: _descCtrl,
            maxLines: 5,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Ceritakan aktivitas/pekerjaan yang Anda lakukan...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF007AFF),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Lampiran',
          icon: Icons.attach_file_rounded,
          trailing: Text(
            '${_attachments.length}/$_maxAttachments',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildUploadButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                      onTap: _pickFromCamera,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUploadButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri',
                      onTap: _pickFromGallery,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUploadButton(
                      icon: Icons.attach_file_rounded,
                      label: 'File',
                      onTap: _pickFiles,
                    ),
                  ),
                ],
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...List.generate(_attachments.length, _buildAttachmentTile),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Reusable pieces ────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF007AFF)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: Color(0xFF4B5563),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Color(0xFF007AFF),
            ),
            const SizedBox(width: 10),
            Text(
              '${_selectedDate.day.toString().padLeft(2, '0')}/'
              '${_selectedDate.month.toString().padLeft(2, '0')}/'
              '${_selectedDate.year}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.expand_more_rounded, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({required bool isStart}) {
    final value = isStart ? _startTime : _endTime;
    return InkWell(
      onTap: isStart ? _pickStartTime : _pickEndTime,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              isStart ? Icons.login_rounded : Icons.logout_rounded,
              size: 15,
              color: const Color(0xFF007AFF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null
                    ? '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
                    : (isStart ? 'Mulai' : 'Selesai'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: value != null ? Colors.black87 : Colors.grey[400],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    if (_isLoadingMasterData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Kategori tidak tersedia.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          TextButton(
            onPressed: _loadMasterData,
            child: const Text('Muat Ulang', style: TextStyle(fontSize: 12)),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final sel = _selectedCategory?.id == cat.id;
        return InkWell(
          onTap: () => setState(() => _selectedCategory = cat),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF007AFF) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? const Color(0xFF007AFF) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat.icon,
                  size: 14,
                  color: sel ? Colors.white : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OfficeLocation>(
          value: _selectedOfficeLocation,
          isExpanded: true,
          hint: Text(
            _isLoadingMasterData ? 'Memuat lokasi...' : 'Pilih lokasi kantor',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          items: _officeLocations
              .map(
                (loc) => DropdownMenuItem(
                  value: loc,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF007AFF),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          loc.officeName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedOfficeLocation = v),
        ),
      ),
    );
  }

  Widget _buildLocationTextField() {
    return TextField(
      controller: _locationCtrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Contoh: Site Bekasi lantai 2, ruang meeting A',
        hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
        prefixIcon: const Icon(
          Icons.edit_location_alt_outlined,
          size: 18,
          color: Color(0xFF007AFF),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF007AFF), size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF007AFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(int i) {
    final att = _attachments[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: att.isImage && att.bytes != null
                ? Image.memory(
                    att.bytes!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: Colors.white,
                    child: Icon(
                      _fileIcon(att.fileType),
                      color: Colors.grey[600],
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(att.sizeBytes),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
            onPressed: () => _removeAttachment(i),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Text(
              'Simpan Aktivitas',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _buildBottomSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(height: 48, child: _buildSubmitButton()),
      ),
    );
  }
}
