// widgets/time_off_multi_file_widget.dart — FULL REPLACE
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:absensikaryawan/Services/time_off_model.dart';

// ── Data class untuk file yang dipilih (pending upload) ──────────────────────
class PendingFile {
  final XFile xfile;
  final Uint8List? bytes;
  final int size;

  const PendingFile({required this.xfile, this.bytes, required this.size});

  String get name =>
      xfile.name.isNotEmpty ? xfile.name : xfile.path.split('/').last;
  String get ext =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isImage => ['jpg', 'jpeg', 'png'].contains(ext);

  String get sizeLabel {
    final mb = size / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(size / 1024).toStringAsFixed(0)} KB';
  }
}

// ── Widget utama ──────────────────────────────────────────────────────────────
class TimeOffMultiFileWidget extends StatefulWidget {
  final List<PendingFile> pendingFiles;
  final List<TimeOffFileItem>? existingFiles;
  final ValueChanged<List<PendingFile>> onFilesChanged;
  final Future<void> Function(TimeOffFileItem)? onDeleteExisting;
  final bool isRequired;
  final bool isEditMode;

  const TimeOffMultiFileWidget({
    super.key,
    required this.pendingFiles,
    this.existingFiles,
    required this.onFilesChanged,
    this.onDeleteExisting,
    this.isRequired = false,
    this.isEditMode = false,
  });

  @override
  State<TimeOffMultiFileWidget> createState() => _TimeOffMultiFileWidgetState();
}

class _TimeOffMultiFileWidgetState extends State<TimeOffMultiFileWidget> {
  // FIX: harusnya int, bukan bool
  int _deletingId = -1;

  // ── File picking ──────────────────────────────────────────────────────────
  Future<void> _pickFiles() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Tambah File',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue[600]),
              ),
              title: const Text(
                'Kamera',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickCamera();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library, color: Colors.green[600]),
              ),
              title: const Text(
                'Galeri / Foto',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickGallery();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.insert_drive_file, color: Colors.orange[600]),
              ),
              title: const Text(
                'File Dokumen (PDF)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCamera() async {
    if (kIsWeb) {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (r != null) await _addFromPicker(r.files);
    } else {
      final img = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (img != null) await _addXFile(img);
    }
  }

  Future<void> _pickGallery() async {
    if (kIsWeb) {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (r != null) await _addFromPicker(r.files);
    } else {
      final imgs = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      // FIX: bungkus body for-loop dalam block {}
      for (final img in imgs) {
        await _addXFile(img);
      }
    }
  }

  Future<void> _pickDocument() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (r != null) await _addFromPicker(r.files);
  }

  Future<void> _addXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (!_validate(file.name, bytes.length)) return;
      final updated = [
        ...widget.pendingFiles,
        PendingFile(xfile: file, bytes: bytes, size: bytes.length),
      ];
      widget.onFilesChanged(updated);
    } catch (e) {
      _showError('Gagal memproses file: $e');
    }
  }

  Future<void> _addFromPicker(List<PlatformFile> files) async {
    final newList = List<PendingFile>.from(widget.pendingFiles);
    for (final f in files) {
      try {
        Uint8List? bytes;
        XFile xfile;
        // FIX: kIsWeb adalah bool, tidak perlu cast
        if (kIsWeb || f.bytes != null) {
          bytes = f.bytes;
          if (bytes == null) {
            _showError('${f.name}: tidak dapat dibaca');
            continue;
          }
          xfile = XFile.fromData(bytes, name: f.name);
        } else if (f.path != null) {
          xfile = XFile(f.path!);
          bytes = await xfile.readAsBytes();
        } else {
          continue;
        }
        if (!_validate(f.name, bytes.length)) continue;
        newList.add(
          PendingFile(xfile: xfile, bytes: bytes, size: bytes.length),
        );
      } catch (e) {
        _showError('${f.name}: $e');
      }
    }
    widget.onFilesChanged(newList);
  }

  bool _validate(String name, int size) {
    if (size > 10 * 1024 * 1024) {
      _showError('$name: Ukuran maksimal 10MB');
      return false;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
      _showError('$name: Format tidak didukung (JPG/PNG/PDF)');
      return false;
    }
    return true;
  }

  void _removePending(int index) {
    final updated = [...widget.pendingFiles]..removeAt(index);
    widget.onFilesChanged(updated);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasAnyFile =
        (widget.existingFiles?.isNotEmpty ?? false) ||
        widget.pendingFiles.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // FIX: ganti withOpacity → withValues
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.upload_file_outlined,
                size: 20,
                color: widget.isRequired
                    ? Colors.red[600]
                    : const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.isRequired
                  ? 'Upload File (Wajib)'
                  : 'Upload File (Opsional)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const Spacer(),
            if (hasAnyFile)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(widget.existingFiles?.length ?? 0) + widget.pendingFiles.length} file',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isRequired ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isRequired
                        ? Colors.red[200]!
                        : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isRequired
                          ? Icons.warning_rounded
                          : Icons.info_outline,
                      size: 16,
                      color: widget.isRequired
                          ? Colors.red[600]
                          : Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isRequired
                            ? 'Upload surat dokter atau keterangan medis (WAJIB)'
                            : 'Bisa upload lebih dari satu file. JPG, PNG, atau PDF (Max 10MB/file)',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isRequired
                              ? Colors.red[700]
                              : Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Existing files
              if (widget.existingFiles != null &&
                  widget.existingFiles!.isNotEmpty) ...[
                const Text(
                  'File tersimpan:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.existingFiles!.map((f) => _buildExistingFileRow(f)),
                const SizedBox(height: 12),
              ],

              // Pending files
              if (widget.pendingFiles.isNotEmpty) ...[
                const Text(
                  'File baru:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.pendingFiles.asMap().entries.map(
                  (e) => _buildPendingFileRow(e.key, e.value),
                ),
                const SizedBox(height: 12),
              ],

              // Tombol tambah
              GestureDetector(
                onTap: _pickFiles,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !hasAnyFile && widget.isRequired
                          ? Colors.red[300]!
                          : const Color(0xFF3B82F6),
                      width: !hasAnyFile && widget.isRequired ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: !hasAnyFile && widget.isRequired
                            ? Colors.red[500]
                            : const Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasAnyFile ? 'Tambah File Lagi' : '+ Upload File',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !hasAnyFile && widget.isRequired
                              ? Colors.red[600]
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExistingFileRow(TimeOffFileItem file) {
    // FIX: _deletingId adalah int, bandingkan dengan int
    final isDeleting = _deletingId == file.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(_fileIcon(file.ext), color: _fileColor(file.ext), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (file.sizeLabel.isNotEmpty)
                  Text(
                    file.sizeLabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Tersimpan',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (isDeleting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (widget.onDeleteExisting != null)
            GestureDetector(
              onTap: () async {
                final confirm = await _confirmDelete(file.fileName);
                if (!confirm) return;
                // FIX: set ke int id
                setState(() => _deletingId = file.id);
                await widget.onDeleteExisting!(file);
                if (mounted) setState(() => _deletingId = -1);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.close, color: Colors.red[600], size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingFileRow(int index, PendingFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(_fileIcon(file.ext), color: _fileColor(file.ext), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  file.sizeLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Baru',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removePending(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.close, color: Colors.red[600], size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String fileName) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Hapus File'),
            content: Text('Hapus "$fileName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _fileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red[600]!;
      case 'jpg':
      case 'jpeg':
        return Colors.blue[600]!;
      case 'png':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}
