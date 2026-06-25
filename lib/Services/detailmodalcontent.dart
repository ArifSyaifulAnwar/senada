// lib/Services/detailmodalcontent.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:absensikaryawan/Screen%20admin/service/web_preview.dart';
import 'package:absensikaryawan/Services/reimbursementmodel.dart';
import 'package:absensikaryawan/Services/reimbursementservice.dart';
import 'package:absensikaryawan/Services/web_download.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class DetailModalContent extends StatefulWidget {
  final ReimbursementData initialItem;
  final ReimbursementService reimbursementService;
  final String? currentUserId;
  final double Function(BuildContext, double) getResponsiveFontSize;
  final double Function(BuildContext, double) getResponsivePadding;
  final String Function(DateTime) formatDateTime;
  final Widget Function(String, String) buildDetailRow;

  const DetailModalContent({
    super.key,
    required this.initialItem,
    required this.reimbursementService,
    required this.currentUserId,
    required this.getResponsiveFontSize,
    required this.getResponsivePadding,
    required this.formatDateTime,
    required this.buildDetailRow,
  });

  @override
  State<DetailModalContent> createState() => _DetailModalContentState();
}

class _DetailModalContentState extends State<DetailModalContent> {
  ReimbursementData? _detailItem;
  ReimbursementAttachment? _receiptAttachment;
  ReimbursementAttachment? _paymentProofAttachment;

  bool _isLoading = true;
  bool _isLoadingReceipt = false;
  bool _isLoadingPaymentProof = false;
  bool _isAttachmentProcessing = false;
  bool _isPaymentProofProcessing = false;

  String? _error;
  String? _receiptError;
  String? _paymentProofError;

  bool _hasPaymentProof(ReimbursementData item) {
    return item.hasPaymentProof ||
        (item.paymentProofFilename?.trim().isNotEmpty == true);
  }

  @override
  void initState() {
    super.initState();
    _loadDetailData();
  }

  Future<void> _loadDetailData() async {
    try {
      final detail = await widget.reimbursementService.getReimbursementDetail(
        id: widget.initialItem.id,
        userId: widget.currentUserId,
      );

      final result = detail ?? widget.initialItem;

      if (!mounted) return;
      setState(() {
        _detailItem = result;
        _isLoading = false;
        _error = null;
      });

      if (result.hasReceipt) {
        _loadReceiptAttachment(result);
      }

      if (_hasPaymentProof(result)) {
        _loadPaymentProofAttachment(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailItem = widget.initialItem;
        _isLoading = false;
        _error = e.toString();
      });

      if (widget.initialItem.hasReceipt) {
        _loadReceiptAttachment(widget.initialItem);
      }

      if (_hasPaymentProof(widget.initialItem)) {
        _loadPaymentProofAttachment(widget.initialItem);
      }
    }
  }

  Future<void> _loadReceiptAttachment(
    ReimbursementData item, {
    bool showError = false,
  }) async {
    if (_isLoadingReceipt) return;

    if (mounted) {
      setState(() {
        _isLoadingReceipt = true;
        _receiptError = null;
      });
    }

    try {
      final attachment = await widget.reimbursementService.getReceiptAttachment(
        id: item.id,
        userId: widget.currentUserId,
      );

      if (!mounted) return;
      setState(() {
        _receiptAttachment = attachment;
        _isLoadingReceipt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _receiptAttachment = null;
        _isLoadingReceipt = false;
        _receiptError = e.toString();
      });

      if (showError) {
        _showError('Gagal memuat bukti pembayaran: $e');
      }
    }
  }

  Future<void> _loadPaymentProofAttachment(
    ReimbursementData item, {
    bool showError = false,
  }) async {
    if (_isLoadingPaymentProof) return;

    if (mounted) {
      setState(() {
        _isLoadingPaymentProof = true;
        _paymentProofError = null;
      });
    }

    try {
      final attachment = await widget.reimbursementService
          .getPaymentProofAttachment(
            id: item.id,
            userId: widget.currentUserId,
            fallbackFileName: item.paymentProofFilename,
          );

      if (!mounted) return;

      setState(() {
        _paymentProofAttachment = attachment;
        _isLoadingPaymentProof = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _paymentProofAttachment = null;
        _isLoadingPaymentProof = false;
        _paymentProofError = e.toString();
      });

      if (showError) {
        _showError('Gagal memuat bukti transfer Finance: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleReceipt({required bool preview}) async {
    if (_isAttachmentProcessing || _detailItem == null) return;

    setState(() => _isAttachmentProcessing = true);

    try {
      final attachment =
          _receiptAttachment ??
          await widget.reimbursementService.getReceiptAttachment(
            id: _detailItem!.id,
            userId: widget.currentUserId,
          );

      if (mounted && _receiptAttachment == null) {
        setState(() => _receiptAttachment = attachment);
      }

      if (preview) {
        await _previewAttachment(attachment);
      } else {
        await _downloadAttachment(attachment);
      }
    } catch (e) {
      _showError('Gagal memproses bukti pembayaran: $e');
    } finally {
      if (mounted) {
        setState(() => _isAttachmentProcessing = false);
      }
    }
  }

  Future<void> _handlePaymentProof({required bool preview}) async {
    if (_isPaymentProofProcessing || _detailItem == null) return;

    setState(() => _isPaymentProofProcessing = true);

    try {
      final attachment =
          _paymentProofAttachment ??
          await widget.reimbursementService.getPaymentProofAttachment(
            id: _detailItem!.id,
            userId: widget.currentUserId,
            fallbackFileName: _detailItem!.paymentProofFilename,
          );

      if (mounted && _paymentProofAttachment == null) {
        setState(() => _paymentProofAttachment = attachment);
      }

      if (preview) {
        await _previewAttachment(attachment);
      } else {
        await _downloadAttachment(attachment);
      }
    } catch (e) {
      _showError('Gagal memproses bukti transfer Finance: $e');
    } finally {
      if (mounted) {
        setState(() => _isPaymentProofProcessing = false);
      }
    }
  }

  Future<void> _previewAttachment(ReimbursementAttachment attachment) async {
    if (attachment.isImage) {
      await _showImagePreview(attachment);
      return;
    }

    if (kIsWeb) {
      openBytesInBrowser(
        attachment.bytes,
        attachment.fileName,
        attachment.mimeType,
      );
      return;
    }

    final tempDirectory = await getTemporaryDirectory();
    final localFile = File(
      '${tempDirectory.path}/${_safeFileName(attachment.fileName)}',
    );

    await localFile.writeAsBytes(attachment.bytes, flush: true);

    final result = await OpenFile.open(localFile.path);
    if (result.type != ResultType.done && mounted) {
      _showError(
        result.message.isEmpty
            ? 'Tidak ada aplikasi untuk membuka file ini.'
            : result.message,
      );
    }
  }

  Future<void> _downloadAttachment(ReimbursementAttachment attachment) async {
    if (kIsWeb) {
      downloadFileWeb(attachment.bytes, attachment.fileName);
      _showSuccess('File sedang diunduh.');
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final localFile = File(
      '${directory.path}/${_safeFileName(attachment.fileName)}',
    );

    await localFile.writeAsBytes(attachment.bytes, flush: true);
    _showSuccess('File tersimpan: ${localFile.path}');
  }

  Future<void> _showImagePreview(ReimbursementAttachment attachment) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
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
                  width: double.infinity,
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        Uint8List.fromList(attachment.bytes),
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
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'bukti_reimbursement' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(widget.getResponsivePadding(context, 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              if (_isLoading) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Memuat detail...'),
                    ],
                  ),
                ),
              ] else if (_detailItem != null) ...[
                _buildHeader(_detailItem!),
                SizedBox(height: widget.getResponsivePadding(context, 20)),
                if (_detailItem!.hasReceipt) ...[
                  Text(
                    'Bukti Pembayaran',
                    style: TextStyle(
                      fontSize: widget.getResponsiveFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReceiptPreview(_detailItem!),
                  const SizedBox(height: 20),
                ],

                if (_hasPaymentProof(_detailItem!)) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Bukti Transfer Finance',
                    style: TextStyle(
                      fontSize: widget.getResponsiveFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _detailItem!.paymentProofUploadedAt == null
                        ? 'Bukti transfer diunggah oleh Head Finance'
                        : 'Diupload pada ${widget.formatDateTime(_detailItem!.paymentProofUploadedAt!)}',
                    style: TextStyle(
                      fontSize: widget.getResponsiveFontSize(context, 12),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  if (_detailItem!.paymentProofUploadedBy?.trim().isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Diupload oleh: ${_detailItem!.paymentProofUploadedBy}',
                      style: TextStyle(
                        fontSize: widget.getResponsiveFontSize(context, 12),
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  if (_detailItem!.paymentNotes?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Catatan Finance: ${_detailItem!.paymentNotes!.trim()}',
                      style: TextStyle(
                        fontSize: widget.getResponsiveFontSize(context, 12),
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildPaymentProofPreview(_detailItem!),
                  const SizedBox(height: 20),
                ],
                const Divider(),
                widget.buildDetailRow('Kategori', _detailItem!.category),
                widget.buildDetailRow('Tanggal', _detailItem!.formattedDate),
                widget.buildDetailRow('Jumlah', _detailItem!.formattedAmount),
                widget.buildDetailRow('Status', _detailItem!.statusLabel),
                widget.buildDetailRow(
                  'Diajukan',
                  widget.formatDateTime(_detailItem!.submittedAt),
                ),
                if (_detailItem!.reviewedAt != null) ...[
                  widget.buildDetailRow(
                    'Direview',
                    widget.formatDateTime(_detailItem!.reviewedAt!),
                  ),
                  if (_detailItem!.reviewedBy != null)
                    widget.buildDetailRow(
                      'Direview oleh',
                      _detailItem!.reviewedBy!,
                    ),
                ],
                if (_detailItem!.paidAt != null) ...[
                  widget.buildDetailRow(
                    'Dibayar',
                    widget.formatDateTime(_detailItem!.paidAt!),
                  ),
                  if (_detailItem!.paidBy != null)
                    widget.buildDetailRow('Dibayar oleh', _detailItem!.paidBy!),
                ],
                if (_detailItem!.description?.trim().isNotEmpty == true) ...[
                  const Divider(),
                  widget.buildDetailRow(
                    'Keterangan',
                    _detailItem!.description!.trim(),
                  ),
                ],
                if (_detailItem!.reviewNotes?.trim().isNotEmpty == true) ...[
                  const Divider(),
                  widget.buildDetailRow(
                    'Catatan Review',
                    _detailItem!.reviewNotes!.trim(),
                  ),
                ],
                if (_error != null) ...[
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.orange[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Menggunakan data cache karena: $_error',
                            style: TextStyle(
                              fontSize: widget.getResponsiveFontSize(
                                context,
                                11,
                              ),
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: widget.getResponsivePadding(context, 32)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ReimbursementData item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            item.title,
            style: TextStyle(
              fontSize: widget.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: item.statusColorValue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item.statusLabel,
            style: TextStyle(
              fontSize: widget.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: item.statusColorValue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptPreview(ReimbursementData item) {
    final attachment = _receiptAttachment;

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _isLoadingReceipt
            ? const Center(child: CircularProgressIndicator())
            : attachment == null
            ? _buildReceiptLoadError(item)
            : attachment.isImage
            ? _buildImageReceipt(attachment)
            : _buildDocumentReceipt(attachment),
      ),
    );
  }

  Widget _buildPaymentProofPreview(ReimbursementData item) {
    final attachment = _paymentProofAttachment;

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _isLoadingPaymentProof
            ? const Center(child: CircularProgressIndicator())
            : attachment == null
            ? _buildPaymentProofLoadError(item)
            : attachment.isImage
            ? _buildImagePaymentProof(attachment)
            : _buildDocumentPaymentProof(attachment),
      ),
    );
  }

  Widget _buildPaymentProofLoadError(ReimbursementData item) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 42,
              color: Colors.grey[500],
            ),
            const SizedBox(height: 8),
            Text(
              _paymentProofError ??
                  'Bukti transfer Finance tidak dapat dimuat.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () =>
                  _loadPaymentProofAttachment(item, showError: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePaymentProof(ReimbursementAttachment attachment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Image.memory(
            Uint8List.fromList(attachment.bytes),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('Gambar bukti transfer tidak dapat ditampilkan.'),
            ),
          ),
        ),
        _buildPaymentProofButtons(),
      ],
    );
  }

  Widget _buildDocumentPaymentProof(ReimbursementAttachment attachment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: const Color(0xFFF0FDF4),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  attachment.extension == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.account_balance_outlined,
                  size: 58,
                  color: attachment.extension == 'pdf'
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF16A34A),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    attachment.fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildPaymentProofButtons(),
      ],
    );
  }

  Widget _buildPaymentProofButtons() {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _isPaymentProofProcessing
                ? null
                : () => _handlePaymentProof(preview: true),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF15803D),
              side: const BorderSide(color: Color(0xFF86EFAC)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isPaymentProofProcessing
                ? null
                : () => _handlePaymentProof(preview: false),
            icon: _isPaymentProofProcessing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptLoadError(ReimbursementData item) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 42,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              _receiptError ?? 'Bukti pembayaran tidak dapat dimuat.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _loadReceiptAttachment(item, showError: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageReceipt(ReimbursementAttachment attachment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Image.memory(
            Uint8List.fromList(attachment.bytes),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Text('Gambar tidak dapat ditampilkan.')),
          ),
        ),
        _buildAttachmentButtons(),
      ],
    );
  }

  Widget _buildDocumentReceipt(ReimbursementAttachment attachment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: const Color(0xFFF8FAFC),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  attachment.extension == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 58,
                  color: attachment.extension == 'pdf'
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    attachment.fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildAttachmentButtons(),
      ],
    );
  }

  Widget _buildAttachmentButtons() {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _isAttachmentProcessing
                ? null
                : () => _handleReceipt(preview: true),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isAttachmentProcessing
                ? null
                : () => _handleReceipt(preview: false),
            icon: _isAttachmentProcessing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
