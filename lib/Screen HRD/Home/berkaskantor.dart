// lib/Screen HRD/Home/berkaskantor.dart
// Fitur "Berkas Kantor" — dokumen kantor company-wide (kontrak, SOP, lisensi,
// dll), BUKAN dokumen milik karyawan tertentu. Akses terbatas Head HRD +
// Finance (dicek client-side via OfficeFileService.checkAccess, dan
// divalidasi ulang server-side di setiap endpoint — defense in depth).
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:absensikaryawan/Services/office_file_service.dart';
import 'package:absensikaryawan/Screen%20admin/service/web_preview.dart';
import 'package:absensikaryawan/utils/web_file_download.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BerkasKantorScreen extends StatefulWidget {
  const BerkasKantorScreen({super.key});

  @override
  State<BerkasKantorScreen> createState() => _BerkasKantorScreenState();
}

class _BerkasKantorScreenState extends State<BerkasKantorScreen> {
  String? _userId;

  bool _checkingAccess = true;
  bool _allowed = false;

  bool _loading = true;
  List<OfficeFileItem> _files = [];
  List<OfficeFileCategory> _categories = [];
  String _searchKeyword = '';
  String _categoryFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('UserID');

    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _checkingAccess = false;
        _allowed = false;
      });
      return;
    }

    final access = await OfficeFileService.checkAccess(_userId!);
    if (!mounted) return;
    setState(() {
      _checkingAccess = false;
      _allowed = access.allowed;
    });

    if (access.allowed) {
      await Future.wait([_loadCategories(), _loadFiles()]);
    }
  }

  Future<void> _loadCategories() async {
    final cats = await OfficeFileService.getCategories(_userId!);
    if (!mounted) return;
    setState(() => _categories = cats);
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final files = await OfficeFileService.getAllFiles(_userId!);
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  List<OfficeFileItem> get _filteredFiles {
    final q = _searchKeyword.trim().toLowerCase();
    return _files.where((f) {
      final matchesCategory = _categoryFilter == 'Semua' || f.category == _categoryFilter;
      final matchesSearch = q.isEmpty ||
          f.name.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q) ||
          (f.description ?? '').toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _buildDisplayFileName(OfficeFileItem file) {
    String sanitize(String s) => s.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
    final namePart = sanitize(file.name);
    final dotIndex = file.name.lastIndexOf('.');
    final ext = dotIndex >= 0 ? file.name.substring(dotIndex) : '';
    if (namePart.toLowerCase().endsWith(ext.replaceAll('.', '').toLowerCase())) {
      return file.name;
    }
    return namePart.isEmpty ? 'Berkas$ext' : '$namePart$ext';
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membaca berkas yang dipilih.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ext = file.extension?.toLowerCase() ?? '';
    final mime = _guessMime(ext);

    final result = await showDialog<_OfficeFileFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OfficeFileFormDialog(
        title: 'Unggah Berkas',
        initialFileName: file.name,
        initialBytes: bytes,
        initialMime: mime,
        categories: _categories,
        userId: _userId!,
        onCategoriesChanged: () => _loadCategories(),
      ),
    );
    if (result == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await OfficeFileService.uploadFile(
      userId: _userId!,
      name: result.name,
      category: result.category,
      description: result.description,
      fileContent: result.bytes ?? bytes,
      fileType: result.mimeType ?? mime,
    );

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green : Colors.red,
      ),
    );
    if (res.success) await _loadFiles();
  }

  String _guessMime(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _confirmDelete(OfficeFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Berkas'),
        content: Text('Yakin ingin menghapus "${file.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await OfficeFileService.deleteFile(userId: _userId!, id: file.id);
    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green : Colors.red,
      ),
    );
    if (res.success) await _loadFiles();
  }

  Future<void> _startEdit(OfficeFileItem file) async {
    final result = await showDialog<_OfficeFileFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OfficeFileFormDialog(
        title: 'Edit Berkas',
        existing: file,
        categories: _categories,
        userId: _userId!,
        onCategoriesChanged: () => _loadCategories(),
      ),
    );

    if (result == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await OfficeFileService.updateFile(
      userId: _userId!,
      id: file.id,
      name: result.name,
      category: result.category,
      description: result.description,
      fileContent: result.bytes,
      fileType: result.mimeType,
    );

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green : Colors.red,
      ),
    );
    if (res.success) await _loadFiles();
  }

  Future<void> _openFile(OfficeFileItem file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    Uint8List bytes;
    try {
      bytes = await OfficeFileService.downloadFile(userId: _userId!, id: file.id);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka berkas: $e'), backgroundColor: Colors.red),
      );
      return;
    }
    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    final safeName = _buildDisplayFileName(file);

    if (file.isImage) {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          child: InteractiveViewer(child: Image.memory(bytes)),
        ),
      );
      return;
    }

    if (kIsWeb) {
      openBytesInBrowser(bytes, safeName, file.fileType.isEmpty ? 'application/octet-stream' : file.fileType);
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$safeName';
      final f = File(path);
      await f.writeAsBytes(bytes);
      final openResult = await OpenFile.open(path);
      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada aplikasi untuk membuka berkas ini.')),
        );
      }
    }
  }

  Future<void> _downloadFile(OfficeFileItem file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mengunduh berkas...'),
          ],
        ),
      ),
    );

    Uint8List bytes;
    try {
      bytes = await OfficeFileService.downloadFile(userId: _userId!, id: file.id);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh berkas: $e'), backgroundColor: Colors.red),
      );
      return;
    }
    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    final safeName = _buildDisplayFileName(file);

    if (kIsWeb) {
      downloadFileWeb(safeName, bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berkas sedang diunduh.'), backgroundColor: Colors.green),
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$safeName';
      final f = File(path);
      await f.writeAsBytes(bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berkas tersimpan: $path'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _manageCategoriesDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => _ManageCategoriesDialog(
        userId: _userId!,
        categories: _categories,
        onChanged: () async {
          await _loadCategories();
          if (mounted) setState(() {});
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
          'Berkas Kantor',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_allowed)
            IconButton(
              icon: const Icon(Icons.category_outlined, color: Colors.black87),
              tooltip: 'Kelola Kategori',
              onPressed: _manageCategoriesDialog,
            ),
        ],
      ),
      floatingActionButton: _allowed
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF007AFF),
              onPressed: _pickAndUpload,
              child: const Icon(Icons.upload_file, color: Colors.white),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_checkingAccess) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_allowed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Anda tidak memiliki akses ke Berkas Kantor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fitur ini hanya untuk Head HRD dan Finance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => Future.wait([_loadCategories(), _loadFiles()]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama, kategori, atau deskripsi berkas...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchKeyword = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _categoryChip('Semua'),
                ..._categories.map((c) => _categoryChip(c.name)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Belum ada berkas kantor.',
                              style: TextStyle(color: Colors.black45),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: _filteredFiles.length,
                        itemBuilder: (ctx, i) => _buildFileTile(_filteredFiles[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label) {
    final selected = _categoryFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _categoryFilter = label),
        selectedColor: const Color(0xFF007AFF),
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFileTile(OfficeFileItem file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _openFile(file),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEFF6FF),
            child: Icon(
              file.isImage ? Icons.image_outlined : Icons.description_outlined,
              color: const Color(0xFF007AFF),
            ),
          ),
          title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${file.category} • ${_formatFileSize(file.fileSize)}\n'
            'Oleh ${file.uploadedByName ?? file.uploadedByUserId} • ${DateFormat('dd MMM yyyy').format(file.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'download') _downloadFile(file);
              if (v == 'edit') _startEdit(file);
              if (v == 'delete') _confirmDelete(file);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'download',
                child: Row(children: [Icon(Icons.download, color: Colors.grey), SizedBox(width: 8), Text('Unduh')]),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeFileFormResult {
  final String name;
  final String category;
  final String? description;
  final Uint8List? bytes;
  final String? mimeType;

  _OfficeFileFormResult({
    required this.name,
    required this.category,
    this.description,
    this.bytes,
    this.mimeType,
  });
}

class _OfficeFileFormDialog extends StatefulWidget {
  final String title;
  final String? initialFileName;
  final Uint8List? initialBytes;
  final String? initialMime;
  final OfficeFileItem? existing;
  final List<OfficeFileCategory> categories;
  final String userId;
  final VoidCallback onCategoriesChanged;

  const _OfficeFileFormDialog({
    required this.title,
    this.initialFileName,
    this.initialBytes,
    this.initialMime,
    this.existing,
    required this.categories,
    required this.userId,
    required this.onCategoriesChanged,
  });

  @override
  State<_OfficeFileFormDialog> createState() => _OfficeFileFormDialogState();
}

class _OfficeFileFormDialogState extends State<_OfficeFileFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  String? _selectedCategory;
  Uint8List? _newBytes;
  String? _newMime;
  String? _newFileName;
  bool _addingCategory = false;
  final TextEditingController _newCategoryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? widget.initialFileName ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _selectedCategory = widget.existing?.category;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReplacementFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.bytes == null || picked.bytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membaca berkas.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      _newBytes = picked.bytes;
      _newFileName = picked.name;
      _newMime = _mimeFromExt(picked.extension?.toLowerCase() ?? '');
    });
  }

  String _mimeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _addNewCategory() async {
    final name = _newCategoryCtrl.text.trim();
    if (name.isEmpty) return;
    final res = await OfficeFileService.addCategory(userId: widget.userId, name: name);
    if (!mounted) return;
    if (res.success) {
      widget.categories.add(OfficeFileCategory(id: -1, name: name));
      setState(() {
        _selectedCategory = name;
        _addingCategory = false;
        _newCategoryCtrl.clear();
      });
      widget.onCategoriesChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: Colors.red),
      );
    }
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    final categoryNames = widget.categories.map((c) => c.name).toSet().toList();
    if (_selectedCategory != null && !categoryNames.contains(_selectedCategory)) {
      categoryNames.add(_selectedCategory!);
    }

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _pickReplacementFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_newFileName ?? 'Ganti Berkas (opsional, kosongkan = tetap)'),
                  ),
                ),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Berkas'),
              ),
              const SizedBox(height: 12),
              if (!_addingCategory)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: categoryNames.contains(_selectedCategory) ? _selectedCategory : null,
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        items: categoryNames
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Tambah kategori baru',
                      onPressed: () => setState(() => _addingCategory = true),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Nama kategori baru'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _addNewCategory,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _addingCategory = false),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Deskripsi (opsional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: (_selectedCategory == null || _nameCtrl.text.trim().isEmpty || (!_isEdit && widget.initialBytes == null))
              ? null
              : () {
                  Navigator.pop(
                    context,
                    _OfficeFileFormResult(
                      name: _nameCtrl.text.trim(),
                      category: _selectedCategory!,
                      description: _descCtrl.text.trim(),
                      bytes: _isEdit ? _newBytes : widget.initialBytes,
                      mimeType: _isEdit ? _newMime : widget.initialMime,
                    ),
                  );
                },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _ManageCategoriesDialog extends StatefulWidget {
  final String userId;
  final List<OfficeFileCategory> categories;
  final Future<void> Function() onChanged;

  const _ManageCategoriesDialog({
    required this.userId,
    required this.categories,
    required this.onChanged,
  });

  @override
  State<_ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<_ManageCategoriesDialog> {
  final TextEditingController _newCtrl = TextEditingController();

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    final res = await OfficeFileService.addCategory(userId: widget.userId, name: name);
    if (!mounted) return;
    if (res.success) {
      _newCtrl.clear();
      await widget.onChanged();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rename(OfficeFileCategory c) async {
    final ctrl = TextEditingController(text: c.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nama Kategori'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == c.name) return;

    final res = await OfficeFileService.updateCategory(userId: widget.userId, id: c.id, name: newName);
    if (!mounted) return;
    if (res.success) {
      await widget.onChanged();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deactivate(OfficeFileCategory c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Kategori'),
        content: Text('Kategori "${c.name}" akan disembunyikan dari daftar. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (confirmed != true) return;

    final res = await OfficeFileService.deactivateCategory(userId: widget.userId, id: c.id);
    if (!mounted) return;
    if (res.success) {
      await widget.onChanged();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kelola Kategori'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 260,
              child: widget.categories.isEmpty
                  ? const Center(child: Text('Belum ada kategori.'))
                  : ListView.builder(
                      itemCount: widget.categories.length,
                      itemBuilder: (ctx, i) {
                        final c = widget.categories[i];
                        return ListTile(
                          dense: true,
                          title: Text(c.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _rename(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => _deactivate(c),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCtrl,
                    decoration: const InputDecoration(labelText: 'Kategori baru'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _add),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
      ],
    );
  }
}
