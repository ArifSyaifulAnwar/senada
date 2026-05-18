// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/designnya/attendancecardmodel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiUrl = '$baseURL/api/asn/file/summary/all/data';

class AttendanceSummaryAdmin extends StatefulWidget {
  const AttendanceSummaryAdmin({super.key});

  @override
  State<AttendanceSummaryAdmin> createState() => _AttendanceSummaryAdminState();
}

class _AttendanceSummaryAdminState extends State<AttendanceSummaryAdmin> {
  late Future<List<AttendanceCardModel>> _futureCards;

  @override
  void initState() {
    super.initState();
    _futureCards = fetchSummaryCards();
  }

  static Future<String?> _getToken() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('access_token') && data['access_token'] != null) {
          return data['access_token'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _updateSummaryCard(AttendanceCardModel model) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Gagal mendapatkan access token');

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/file/summary/update/data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'id': model.id,
          'mainText': model.mainText,
          'subText': model.subText,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _refreshData() {
    setState(() {
      _futureCards = fetchSummaryCards();
    });
  }

  Future<void> _saveBreakTimeChange(
    AttendanceCardModel model,
    int minutes,
  ) async {
    try {
      String formattedBreakTime;
      String subText;

      if (minutes >= 60) {
        final hours = minutes ~/ 60;
        final remainingMinutes = minutes % 60;
        if (remainingMinutes == 0) {
          formattedBreakTime = '${hours.toString().padLeft(2, '0')}:00 jam';
          subText = 'Rata-rata $hours jam';
        } else {
          formattedBreakTime =
              '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')} jam';
          subText = 'Rata-rata $hours jam $remainingMinutes menit';
        }
      } else {
        formattedBreakTime = '$minutes mnt';
        subText = 'Rata-rata $minutes menit';
      }

      final updatedModel = AttendanceCardModel(
        id: model.id,
        icon: model.icon,
        iconColor: model.iconColor,
        title: model.title,
        mainText: formattedBreakTime,
        subText: subText,
        urutan: model.urutan,
      );

      final success = await _updateSummaryCard(updatedModel);
      if (success) {
        _refreshData();
      } else {
        throw Exception('Gagal menyimpan perubahan ke server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan perubahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTotalDaysChange(AttendanceCardModel model, int days) async {
    try {
      final updatedModel = AttendanceCardModel(
        id: model.id,
        icon: model.icon,
        iconColor: model.iconColor,
        title: model.title,
        mainText: days.toString(),
        subText: 'Hari Kerja',
        urutan: model.urutan,
      );

      final success = await _updateSummaryCard(updatedModel);
      if (success) {
        _refreshData();
      } else {
        throw Exception('Gagal menyimpan perubahan ke server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan perubahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<AttendanceCardModel>> fetchSummaryCards() async {
    final token = await _getToken();
    if (token == null) throw Exception('Gagal mendapatkan token');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => AttendanceCardModel.fromJson(e)).toList();
    } else {
      throw Exception('Gagal memuat data summary');
    }
  }

  void _showEditDialog(BuildContext context, AttendanceCardModel model) {
    switch (model.title.toLowerCase()) {
      case 'jam masuk':
      case 'jam pulang':
        _showTimePickerDialog(context, model);
        break;
      case 'waktu istirahat':
        _showBreakTimeDialog(context, model);
        break;
      case 'total hari':
        _showTotalDaysDialog(context, model);
        break;
      default:
        _showGenericEditDialog(context, model);
        break;
    }
  }

  Future<void> _saveGenericChange(
    AttendanceCardModel model,
    String value,
  ) async {
    try {
      final updatedModel = AttendanceCardModel(
        id: model.id,
        icon: model.icon,
        iconColor: model.iconColor,
        title: model.title,
        mainText: value,
        subText: model.subText,
        urutan: model.urutan,
      );

      final success = await _updateSummaryCard(updatedModel);
      if (success) {
        _refreshData();
      } else {
        throw Exception('Gagal menyimpan perubahan ke server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan perubahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTimePickerDialog(
    BuildContext context,
    AttendanceCardModel model,
  ) async {
    TimeOfDay initialTime = TimeOfDay.now();
    try {
      String timeText = model.mainText.replaceAll('WIB', '').trim();
      final timeParts = timeText.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (hour != null &&
            minute != null &&
            hour >= 0 &&
            hour <= 23 &&
            minute >= 0 &&
            minute <= 59) {
          initialTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
    } catch (e) {
      initialTime = TimeOfDay.now();
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Pilih ${model.title}',
      cancelText: 'Batal',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: model.getIconColor(),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1F2937),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              dialHandColor: model.getIconColor(),
              dialBackgroundColor: Colors.grey[50],
              dialTextColor: Colors.black87,
              entryModeIconColor: model.getIconColor(),
              dayPeriodColor: model.getIconColor(),
              dayPeriodTextColor: Colors.white,
              hourMinuteColor: model.getIconColor().withOpacity(0.1),
              hourMinuteTextColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      await _saveTimeChange(model, selectedTime);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${model.title} berhasil diubah ke ${selectedTime.format(context)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveTimeChange(
    AttendanceCardModel model,
    TimeOfDay time,
  ) async {
    try {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      final formattedTime = '$hour:$minute';

      final updatedModel = AttendanceCardModel(
        id: model.id,
        icon: model.icon,
        iconColor: model.iconColor,
        title: model.title,
        mainText: formattedTime,
        subText: model.subText,
        urutan: model.urutan,
      );

      final success = await _updateSummaryCard(updatedModel);
      if (success) {
        _refreshData();
      } else {
        throw Exception('Gagal menyimpan perubahan ke server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal menyimpan perubahan: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showBreakTimeDialog(BuildContext context, AttendanceCardModel model) {
    int selectedMinutes = 60;
    try {
      final currentText = model.mainText.replaceAll(RegExp(r'[^\d]'), '');
      if (currentText.isNotEmpty) {
        selectedMinutes = int.parse(currentText);
      }
    } catch (e) {
      selectedMinutes = 60;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    model.getIconData(),
                    color: model.getIconColor(),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit ${model.title}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Durasi Istirahat (menit)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (selectedMinutes > 15) {
                              setDialogState(() => selectedMinutes -= 15);
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          color: model.getIconColor(),
                        ),
                        Text(
                          '$selectedMinutes menit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: model.getIconColor(),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (selectedMinutes < 180) {
                              setDialogState(() => selectedMinutes += 15);
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          color: model.getIconColor(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rentang: 15 - 180 menit',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveBreakTimeChange(model, selectedMinutes);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Waktu istirahat berhasil diubah ke $selectedMinutes menit',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: model.getIconColor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTotalDaysDialog(BuildContext context, AttendanceCardModel model) {
    int selectedDays = 22;
    try {
      final currentText = model.mainText.replaceAll(RegExp(r'[^\d]'), '');
      if (currentText.isNotEmpty) {
        selectedDays = int.parse(currentText);
      }
    } catch (e) {
      selectedDays = 22;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    model.getIconData(),
                    color: model.getIconColor(),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit ${model.title}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Hari Kerja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (selectedDays > 1) {
                              setDialogState(() => selectedDays--);
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          color: model.getIconColor(),
                        ),
                        Text(
                          '$selectedDays hari',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: model.getIconColor(),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (selectedDays < 31) {
                              setDialogState(() => selectedDays++);
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          color: model.getIconColor(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rentang: 1 - 31 hari',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveTotalDaysChange(model, selectedDays);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Total hari kerja berhasil diubah ke $selectedDays hari',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: model.getIconColor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGenericEditDialog(BuildContext context, AttendanceCardModel model) {
    final TextEditingController controller = TextEditingController(
      text: model.mainText,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(model.getIconData(), color: model.getIconColor(), size: 24),
              const SizedBox(width: 8),
              Text(
                'Edit ${model.title}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: model.title,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: model.getIconColor()),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                _saveGenericChange(model, controller.text);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${model.title} berhasil diubah'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: model.getIconColor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // BUILD UTAMA — responsive grid
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth >= 768;

    // PERBAIKAN UTAMA:
    // Mobile  → padding dari screenWidth penuh (perilaku asli)
    // Web     → padding 0, biarkan parent yang atur padding,
    //           karena widget ini sudah di dalam kolom kanan yang lebih sempit
    final double horizontalPadding = isWeb ? 0 : screenWidth * 0.04;

    const double baseWidth = 375;
    final double scale = isWeb ? 1.0 : screenWidth / baseWidth;
    final double cardSpacing = 12 * scale;

    return FutureBuilder<List<AttendanceCardModel>>(
      future: _futureCards,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada data summary'));
        }

        final cards = snapshot.data!;

        // Web: Row 4 kolom, tinggi mengikuti konten (tidak ada whitespace)
        if (isWeb) {
          final List<Widget> rows = [];
          for (int i = 0; i < cards.length; i += 4) {
            final rowCards = cards.sublist(
              i,
              i + 4 > cards.length ? cards.length : i + 4,
            );
            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int j = 0; j < rowCards.length; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(child: _buildCard(context, rowCards[j], scale)),
                  ],
                  for (int j = rowCards.length; j < 4; j++) ...[
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ],
              ),
            );
            if (i + 4 < cards.length) rows.add(const SizedBox(height: 12));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          );
        }

        // Mobile: layout 2 kolom asli (Row pairs)
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: List.generate((cards.length / 2).ceil(), (index) {
              final first = cards[index * 2];
              final second = (index * 2 + 1 < cards.length)
                  ? cards[index * 2 + 1]
                  : null;

              return Padding(
                padding: EdgeInsets.only(bottom: cardSpacing),
                child: Row(
                  children: [
                    Expanded(child: _buildCard(context, first, scale)),
                    if (second != null) ...[
                      SizedBox(width: cardSpacing),
                      Expanded(child: _buildCard(context, second, scale)),
                    ] else
                      const Expanded(child: SizedBox()),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    AttendanceCardModel model,
    double scale,
  ) {
    final bool isWeb = MediaQuery.of(context).size.width >= 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 14 : 16 * scale,
        vertical: isWeb ? 12 : 16 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: icon + judul + edit
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: model.getIconColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  model.getIconData(),
                  color: model.getIconColor(),
                  size: 14,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  model.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              GestureDetector(
                onTap: () => _showEditDialog(context, model),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(Icons.edit, size: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Nilai utama
          Text(
            model.mainText,
            style: TextStyle(
              fontSize: isWeb ? 16 : 18 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 3),
          // Sub teks
          Text(
            model.subText,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
