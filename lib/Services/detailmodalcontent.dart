// Update file: lib/Services/detailmodalcontent.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:absensikaryawan/widget/authenticated_image.dart';
import 'package:flutter/material.dart';
import 'package:absensikaryawan/Services/reimbursementmodel.dart';
import 'package:absensikaryawan/Services/reimbursementservice.dart';

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
  _DetailModalContentState createState() => _DetailModalContentState();
}

class _DetailModalContentState extends State<DetailModalContent> {
  ReimbursementData? _detailItem;
  bool _isLoading = true;
  String? _error;

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

      setState(() {
        _detailItem = detail ?? widget.initialItem;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _detailItem = widget.initialItem; // Fallback ke data awal
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _downloadReceipt() async {
    if (_detailItem == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Mendownload file...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Mohon tunggu sebentar',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );

      final file = await widget.reimbursementService.downloadReceipt(
        id: _detailItem!.id,
        userId: widget.currentUserId,
      );

      Navigator.pop(context); // Close loading dialog

      if (file != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'File berhasil didownload!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tersimpan di folder Download',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'BUKA',
              textColor: Colors.white,
              onPressed: () async {
                await widget.reimbursementService.openDownloadedFile(file);
              },
            ),
          ),
        );

        // Auto open file after 1 second delay
        await Future.delayed(Duration(seconds: 1));
        await widget.reimbursementService.openDownloadedFile(file);
      } else {
        _showError('Gagal mendownload file');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showError('Terjadi kesalahan saat mendownload file: $e');
    }
  }

  // Test receipt URL manually
  Future<void> _testReceiptUrl() async {
    if (_detailItem == null) return;

    await widget.reimbursementService.testReceiptImageAccess(
      _detailItem!.id,
      userId: widget.currentUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(widget.getResponsivePadding(context, 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),

              // Loading state
              if (_isLoading) ...[
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Memuat detail...'),
                    ],
                  ),
                ),
              ] else if (_detailItem != null) ...[
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _detailItem!.title,
                        style: TextStyle(
                          fontSize: widget.getResponsiveFontSize(context, 18),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _detailItem!.statusColorValue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _detailItem!.statusText,
                        style: TextStyle(
                          fontSize: widget.getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: _detailItem!.statusColorValue,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: widget.getResponsivePadding(context, 20)),

                // Receipt Preview
                if (_detailItem!.hasReceipt) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bukti Pembayaran',
                        style: TextStyle(
                          fontSize: widget.getResponsiveFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  _buildReceiptPreview(_detailItem!),
                  SizedBox(height: 20),
                ],

                Divider(),

                // Details
                widget.buildDetailRow('Kategori', _detailItem!.category),
                widget.buildDetailRow('Tanggal', _detailItem!.formattedDate),
                widget.buildDetailRow('Jumlah', _detailItem!.formattedAmount),
                widget.buildDetailRow('Status', _detailItem!.statusText),
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

                if (_detailItem!.description != null &&
                    _detailItem!.description!.isNotEmpty) ...[
                  Divider(),
                  widget.buildDetailRow(
                    'Keterangan',
                    _detailItem!.description!,
                  ),
                ],

                if (_detailItem!.reviewNotes != null &&
                    _detailItem!.reviewNotes!.isNotEmpty) ...[
                  Divider(),
                  widget.buildDetailRow(
                    'Catatan Review',
                    _detailItem!.reviewNotes!,
                  ),
                ],

                if (_error != null) ...[
                  Divider(),
                  Container(
                    padding: EdgeInsets.all(12),
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
                        SizedBox(width: 8),
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

  Widget _buildReceiptPreview(ReimbursementData item) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _buildReceiptContent(item),
      ),
    );
  }

  Widget _buildReceiptContent(ReimbursementData item) {
    final receiptUrl = widget.reimbursementService.getReceiptImageUrl(
      item.id,
      userId: widget.currentUserId,
    );

    // Determine if it's likely an image based on filename
    final isLikelyImage =
        item.receiptFilename?.toLowerCase().contains(
          RegExp(r'\.(jpg|jpeg|png)$'),
        ) ??
        false;

    if (isLikelyImage) {
      return Stack(
        children: [
          AuthenticatedImage(
            url: receiptUrl,
            getHeaders: widget
                .reimbursementService
                .getHeaders, // Changed from _getHeaders to getHeaders
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: () => Container(
              color: Colors.grey[100],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text(
                      'Loading receipt image...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            errorWidget: (error) => Container(
              color: Colors.grey[100],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load receipt',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _testReceiptUrl,
                      icon: Icon(Icons.bug_report, size: 16),
                      label: Text('Debug URL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: ElevatedButton.icon(
              onPressed: _downloadReceipt,
              icon: Icon(Icons.download, size: 16),
              label: Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      );
    } else {
      // Show PDF or file icon
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 64,
                color: Colors.red[400],
              ),
              SizedBox(height: 12),
              Text(
                item.receiptFilename ?? 'Bukti Pembayaran',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'PDF Document',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _downloadReceipt,
                icon: Icon(Icons.download, size: 16),
                label: Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
