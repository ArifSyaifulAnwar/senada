// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:absensikaryawan/Services/teguran_service.dart';
import 'package:absensikaryawan/utils/web_file_download.dart';

class WarningLetter {
  final int id;
  final String noSurat;
  final String tanggal;
  final String judul;
  final String deskripsi;
  final String level; // e.g. "Verbal", "SP1", "SP2", "SP3"

  WarningLetter({
    required this.id,
    required this.noSurat,
    required this.tanggal,
    required this.judul,
    required this.deskripsi,
    required this.level,
  });

  factory WarningLetter.fromTeguranData(TeguranData data) {
    return WarningLetter(
      id: data.id,
      noSurat: data.noSurat,
      tanggal: DateFormat('d MMMM yyyy', 'id_ID').format(data.tanggal),
      judul: data.judul,
      deskripsi: data.deskripsi ?? '-',
      level: data.level,
    );
  }
}

class WarningLetterScreen extends StatefulWidget {
  final String userId;

  const WarningLetterScreen({super.key, required this.userId});

  @override
  State<WarningLetterScreen> createState() => _WarningLetterScreenState();
}

class _WarningLetterScreenState extends State<WarningLetterScreen> {
  List<WarningLetter> _warningList = [];
  bool _loading = true;
  String? _errorMessage;
  final Set<int> _downloadingIds = {};

  Future<void> _downloadAndOpenSurat(int id) async {
    setState(() => _downloadingIds.add(id));
    try {
      final bytes = await TeguranService.downloadTeguranPdf(id);
      final fileName = 'SuratTeguran_$id.pdf';

      if (kIsWeb) {
        downloadFileWeb(fileName, bytes);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka surat: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(id));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTeguran();
  }

  Future<void> _loadTeguran() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await TeguranService.getMyTeguran(widget.userId);
      if (!mounted) return;
      setState(() {
        _warningList = list.map((e) => WarningLetter.fromTeguranData(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data teguran: $e';
        _loading = false;
      });
    }
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case "SP1":
        return Colors.orange;
      case "SP2":
        return Colors.deepOrange;
      case "SP3":
        return Colors.red;
      case "Verbal":
      default:
        return Colors.blueAccent;
    }
  }

  IconData _iconForLevel(String level) {
    switch (level) {
      case "SP1":
        return Icons.warning_amber_rounded;
      case "SP2":
        return Icons.error_outline;
      case "SP3":
        return Icons.report;
      case "Verbal":
      default:
        return Icons.record_voice_over;
    }
  }

  String _labelForLevel(String level) {
    switch (level) {
      case "SP1":
        return "Teguran I";
      case "SP2":
        return "Teguran II";
      case "SP3":
        return "Teguran III";
      case "Verbal":
      default:
        return "Lisan";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil lebar screen, buat responsive
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardPadding = screenWidth < 360
        ? 12
        : screenWidth < 480
        ? 16
        : 20;
    final double cardFont = screenWidth < 380
        ? 13
        : screenWidth < 480
        ? 14
        : 15;
    final double iconSize = screenWidth < 360
        ? 20
        : screenWidth < 480
        ? 22
        : 26;
    final double titleFont = screenWidth < 380
        ? 14
        : screenWidth < 480
        ? 15
        : 16;
    final double subtitleFont = screenWidth < 380
        ? 11
        : screenWidth < 480
        ? 12
        : 13;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Teguran',
          style: TextStyle(
            fontSize: cardFont + 6,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: _loadTeguran,
            child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: cardPadding.toDouble(),
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  padding: EdgeInsets.all(cardPadding + 4.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(cardPadding.toDouble()),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: iconSize + 2,
                        ),
                      ),
                      SizedBox(width: cardPadding.toDouble()),
                      Expanded(
                        child: Text(
                          'Daftar Teguran',
                          style: TextStyle(
                            fontSize: titleFont + 3,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Daftar Teguran List
                if (_loading)
                  Container(
                    margin: const EdgeInsets.only(top: 80),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 50),
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: titleFont, color: Colors.grey),
                      ),
                    ),
                  )
                else if (_warningList.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 50),
                    child: Center(
                      child: Text(
                        "Belum ada teguran.",
                        style: TextStyle(
                          fontSize: titleFont,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                else
                  ..._warningList.map(
                    (w) => Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: cardPadding / 2,
                          horizontal: cardPadding,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _colorForLevel(
                              w.level,
                            ).withOpacity(0.13),
                            radius: cardPadding + 2,
                            child: Icon(
                              _iconForLevel(w.level),
                              color: _colorForLevel(w.level),
                              size: iconSize + 1,
                            ),
                          ),
                          title: Wrap(
                            alignment: WrapAlignment.start,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                w.judul,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: titleFont,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: screenWidth < 340 ? 6 : 9,
                                ),
                                decoration: BoxDecoration(
                                  color: _colorForLevel(
                                    w.level,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _iconForLevel(w.level),
                                      size: subtitleFont + 2,
                                      color: _colorForLevel(w.level),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      _labelForLevel(w.level),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: subtitleFont + 1,
                                        color: _colorForLevel(w.level),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: subtitleFont - 8),
                              Text(
                                w.deskripsi,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: subtitleFont,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: subtitleFont,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    w.tanggal,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: subtitleFont,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Icon(
                                    Icons.confirmation_number,
                                    size: subtitleFont,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      w.noSurat,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: subtitleFont,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: _downloadingIds.contains(w.id)
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.picture_as_pdf_outlined),
                                  color: _colorForLevel(w.level),
                                  tooltip: 'Lihat/Unduh Surat',
                                  onPressed: () => _downloadAndOpenSurat(w.id),
                                ),
                          minVerticalPadding: 0,
                          dense: screenWidth < 380,
                          visualDensity: screenWidth < 400
                              ? VisualDensity.compact
                              : VisualDensity.standard,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}
