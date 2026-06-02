// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:excel/excel.dart' as ex;
import 'package:intl/intl.dart';
import '../../Screen admin/model/admin_attendance_model.dart';

class ExcelExportService {
  static List<int>? buildAbsensiExcel(
    List<AdminAttendanceData> data, {
    String? periodLabel,
    Map<String, String>? doaMap,
  }) {
    final excel = ex.Excel.createExcel();
    const sheetName = 'Data Absensi';
    ex.Sheet sheet = excel[sheetName];
    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);

    // ── Warna ────────────────────────────────────────────────────────────
    const headerBg = '#1E3A5F';
    const subHeaderBg = '#2E86C1';
    const altRowBg = '#EBF5FB';
    const whiteBg = '#FFFFFF';
    const headerFg = '#FFFFFF';
    const borderHex = '#AED6F1';

    // ── Helpers ──────────────────────────────────────────────────────────
    ex.Border thinBorder() => ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );

    ex.CellStyle makeStyle({
      String bgColor = whiteBg,
      String fontColor = '#000000',
      bool bold = false,
      bool italic = false,
      int fontSize = 10,
      ex.HorizontalAlign hAlign = ex.HorizontalAlign.Left,
      ex.VerticalAlign vAlign = ex.VerticalAlign.Center,
      bool hasBorder = true,
    }) {
      final b = hasBorder
          ? thinBorder()
          : ex.Border(borderStyle: ex.BorderStyle.None);
      return ex.CellStyle(
        backgroundColorHex: ex.ExcelColor.fromHexString(bgColor),
        fontColorHex: ex.ExcelColor.fromHexString(fontColor),
        bold: bold,
        italic: italic,
        fontSize: fontSize,
        horizontalAlign: hAlign,
        verticalAlign: vAlign,
        leftBorder: b,
        rightBorder: b,
        topBorder: b,
        bottomBorder: b,
      );
    }

    // ── Row 1: Judul — sekarang 9 kolom (A–I) ───────────────────────────
    sheet.cell(ex.CellIndex.indexByString('A1')).value = ex.TextCellValue(
      'LAPORAN DATA ABSENSI KARYAWAN',
    );
    sheet.cell(ex.CellIndex.indexByString('A1')).cellStyle = makeStyle(
      bgColor: headerBg,
      fontColor: headerFg,
      bold: true,
      fontSize: 14,
      hAlign: ex.HorizontalAlign.Center,
      hasBorder: false,
    );
    sheet.merge(
      ex.CellIndex.indexByString('A1'),
      ex.CellIndex.indexByString('I1'),
    );

    // ── Row 2: Periode + Dicetak ─────────────────────────────────────────
    final now = DateTime.now();
    final period =
        periodLabel ?? 'Per ${DateFormat('dd MMMM yyyy', 'id_ID').format(now)}';
    final printDate =
        'Dicetak: ${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(now)}';

    final subInfoStyle = makeStyle(
      bgColor: subHeaderBg,
      fontColor: headerFg,
      italic: true,
      fontSize: 9,
      hAlign: ex.HorizontalAlign.Center,
      hasBorder: false,
    );
    sheet.cell(ex.CellIndex.indexByString('A2')).value = ex.TextCellValue(
      'Periode: $period',
    );
    sheet.cell(ex.CellIndex.indexByString('A2')).cellStyle = subInfoStyle;
    sheet.merge(
      ex.CellIndex.indexByString('A2'),
      ex.CellIndex.indexByString('E2'),
    );

    sheet.cell(ex.CellIndex.indexByString('F2')).value = ex.TextCellValue(
      printDate,
    );
    sheet.cell(ex.CellIndex.indexByString('F2')).cellStyle = subInfoStyle;
    sheet.merge(
      ex.CellIndex.indexByString('F2'),
      ex.CellIndex.indexByString('I2'),
    );

    // ── Row 3: Spacer ────────────────────────────────────────────────────
    sheet.cell(ex.CellIndex.indexByString('A3')).value = ex.TextCellValue('');

    // ── Row 4: Header kolom — 9 kolom (ditambah Lembur) ──────────────────
    const headers = [
      'No',
      'Nama Karyawan',
      'Departemen',
      'Tanggal',
      'Jam Masuk',
      'Jam Keluar',
      'Lembur',
      'Status',
      'Doa',
    ];
    final headerStyle = makeStyle(
      bgColor: subHeaderBg,
      fontColor: headerFg,
      bold: true,
      fontSize: 10,
      hAlign: ex.HorizontalAlign.Center,
    );
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3),
      );
      cell.value = ex.TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // ── Lebar kolom ──────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 6); // No
    sheet.setColumnWidth(1, 28); // Nama
    sheet.setColumnWidth(2, 18); // Dept
    sheet.setColumnWidth(3, 16); // Tanggal
    sheet.setColumnWidth(4, 12); // Jam Masuk
    sheet.setColumnWidth(5, 12); // Jam Keluar
    sheet.setColumnWidth(6, 12); // Lembur
    sheet.setColumnWidth(7, 22); // Status
    sheet.setColumnWidth(8, 10); // Doa

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 18);
    sheet.setRowHeight(3, 22);

    // ── Kelompokkan per karyawan ─────────────────────────────────────────
    final grouped = <String, List<AdminAttendanceData>>{};
    for (final d in data) {
      grouped.putIfAbsent(d.userId, () => []).add(d);
    }

    final maxPerKaryawan = grouped.values
        .map((v) => v.length)
        .fold(0, (a, b) => a > b ? a : b);
    final isMultiHari = maxPerKaryawan > 1;

    // ── Tulis data row ───────────────────────────────────────────────────
    int rowIndex = 4;
    int no = 1;

    int grandTotal = 0,
        grandTepat = 0,
        grandTerlambat = 0,
        grandCuti = 0,
        grandTidakHadir = 0,
        grandIkutDoa = 0,
        grandTidakDoa = 0,
        grandLemburMinutes = 0;

    for (final entry in grouped.entries) {
      final rows = entry.value;

      for (int i = 0; i < rows.length; i++) {
        final d = rows[i];
        final rowBg = no % 2 == 1 ? whiteBg : altRowBg;

        final baseStyle = makeStyle(bgColor: rowBg);
        final centerStyle = makeStyle(
          bgColor: rowBg,
          hAlign: ex.HorizontalAlign.Center,
        );
        final statusStyle = _statusCellStyle(d.displayStatus, rowBg, borderHex);

        final tanggalKey =
            '${DateFormat('yyyy-MM-dd').format(d.attendanceDate)}_${d.userId.toLowerCase()}';
        final doaVal = doaMap?[tanggalKey] ?? '';
        final doaStyle = _doaCellStyle(doaVal, rowBg, borderHex);

        // ── Lembur per baris ──────────────────────────────────────
        final ovtMin = d.overtimeMinutes;
        final hasOvt = ovtMin != null && ovtMin > 0 && ovtMin < 1440;
        final lemburText = hasOvt
            ? '${(ovtMin / 60).toStringAsFixed(1)} jam'
            : '-';
        final lemburStyle = _lemburCellStyle(ovtMin, rowBg, borderHex);

        void setCell(int col, ex.CellValue value, ex.CellStyle style) {
          final cell = sheet.cell(
            ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          );
          cell.value = value;
          cell.cellStyle = style;
        }

        setCell(0, ex.IntCellValue(no), centerStyle);
        setCell(1, ex.TextCellValue(d.userName), baseStyle);
        setCell(2, ex.TextCellValue(d.department ?? '-'), baseStyle);
        setCell(
          3,
          ex.TextCellValue(_formatDate(d.attendanceDate)),
          centerStyle,
        );
        setCell(4, ex.TextCellValue(d.formattedCheckIn), centerStyle);
        setCell(5, ex.TextCellValue(d.formattedCheckOut), centerStyle);
        setCell(6, ex.TextCellValue(lemburText), lemburStyle); // ← Lembur
        setCell(7, ex.TextCellValue(d.displayStatus), statusStyle);
        setCell(8, ex.TextCellValue(doaVal), doaStyle);

        rowIndex++;
        no++;
      }

      // Hitung summary termasuk doa + lembur
      final counts = _countStatus(rows, doaMap);
      grandTotal += counts['total']!;
      grandTepat += counts['tepat']!;
      grandTerlambat += counts['terlambat']!;
      grandCuti += counts['cuti']!;
      grandTidakHadir += counts['tidakHadir']!;
      grandIkutDoa += counts['ikutDoa']!;
      grandTidakDoa += counts['tidakDoa']!;
      grandLemburMinutes += counts['lemburMinutes']!;

      // ── Summary per karyawan (hanya multi-hari) ──────────────────
      if (isMultiHari) {
        rowIndex++; // blank row

        final summaryLabelStyle = makeStyle(
          bgColor: headerBg,
          fontColor: headerFg,
          bold: true,
          fontSize: 9,
          hAlign: ex.HorizontalAlign.Center,
        );

        // Col 0: kosong
        sheet
                .cell(
                  ex.CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: rowIndex,
                  ),
                )
                .cellStyle =
            summaryLabelStyle;
        sheet
            .cell(
              ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = ex.TextCellValue(
          '',
        );

        // Labels di col 1–7 (B–H)
        final summaryLabels = [
          'Total Data',
          'Tepat Waktu',
          'Terlambat',
          'Cuti',
          'Tidak Hadir',
          'Ikut Doa',
          'Tidak Doa',
        ];
        for (int col = 0; col < summaryLabels.length; col++) {
          final cell = sheet.cell(
            ex.CellIndex.indexByColumnRow(
              columnIndex: col + 1,
              rowIndex: rowIndex,
            ),
          );
          cell.value = ex.TextCellValue(summaryLabels[col]);
          cell.cellStyle = summaryLabelStyle;
        }
        // Col 8 (I): label Lembur
        final lblLembur = sheet.cell(
          ex.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
        );
        lblLembur.value = ex.TextCellValue('Lembur (jam)');
        lblLembur.cellStyle = summaryLabelStyle;

        sheet.setRowHeight(rowIndex, 18);
        rowIndex++;

        // Value row
        final summaryValColors = [
          '#EBF5FB',
          '#D5F5E3',
          '#FDEBD0',
          '#D6EAF8',
          '#FADBD8',
          '#D5F5E3',
          '#FADBD8',
        ];
        final summaryFontColors = [
          '#1E3A5F',
          '#1E8449',
          '#784212',
          '#154360',
          '#7B241C',
          '#1E8449',
          '#7B241C',
        ];
        final summaryValues = [
          counts['total']!,
          counts['tepat']!,
          counts['terlambat']!,
          counts['cuti']!,
          counts['tidakHadir']!,
          counts['ikutDoa']!,
          counts['tidakDoa']!,
        ];

        final namaStyle = makeStyle(
          bgColor: '#F2F3F4',
          bold: true,
          fontSize: 9,
          hAlign: ex.HorizontalAlign.Center,
        );
        sheet
            .cell(
              ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = ex.TextCellValue(
          rows[0].userName,
        );
        sheet
                .cell(
                  ex.CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: rowIndex,
                  ),
                )
                .cellStyle =
            namaStyle;

        for (int col = 0; col < summaryValues.length; col++) {
          final cell = sheet.cell(
            ex.CellIndex.indexByColumnRow(
              columnIndex: col + 1,
              rowIndex: rowIndex,
            ),
          );
          cell.value = ex.IntCellValue(summaryValues[col]);
          cell.cellStyle = makeStyle(
            bgColor: summaryValColors[col],
            fontColor: summaryFontColors[col],
            bold: true,
            fontSize: 11,
            hAlign: ex.HorizontalAlign.Center,
          );
        }
        // Col 8 (I): total lembur jam
        final lemburJamGrp = double.parse(
          (counts['lemburMinutes']! / 60).toStringAsFixed(1),
        );
        final valLembur = sheet.cell(
          ex.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
        );
        valLembur.value = ex.DoubleCellValue(lemburJamGrp);
        valLembur.cellStyle = makeStyle(
          bgColor: '#FCF3CF',
          fontColor: '#B9770E',
          bold: true,
          fontSize: 11,
          hAlign: ex.HorizontalAlign.Center,
        );

        sheet.setRowHeight(rowIndex, 22);
        rowIndex++;
        rowIndex++; // extra blank
      }
    }

    // ── Grand Total ──────────────────────────────────────────────────────
    {
      rowIndex++;
      final grandLabelStyle = makeStyle(
        bgColor: '#1A252F',
        fontColor: headerFg,
        bold: true,
        fontSize: 10,
        hAlign: ex.HorizontalAlign.Center,
      );
      final grandTotalLabel = isMultiHari ? 'GRAND TOTAL' : 'TOTAL';
      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          )
          .value = ex.TextCellValue(
        grandTotalLabel,
      );
      sheet
              .cell(
                ex.CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: rowIndex,
                ),
              )
              .cellStyle =
          grandLabelStyle;

      final grandLabels = [
        'Total Data',
        'Tepat Waktu',
        'Terlambat',
        'Cuti',
        'Tidak Hadir',
        'Ikut Doa',
        'Tidak Doa',
      ];
      for (int col = 0; col < grandLabels.length; col++) {
        final cell = sheet.cell(
          ex.CellIndex.indexByColumnRow(
            columnIndex: col + 1,
            rowIndex: rowIndex,
          ),
        );
        cell.value = ex.TextCellValue(grandLabels[col]);
        cell.cellStyle = grandLabelStyle;
      }
      // Col 8 (I): label Lembur
      final gLblLembur = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
      );
      gLblLembur.value = ex.TextCellValue('Lembur (jam)');
      gLblLembur.cellStyle = grandLabelStyle;

      sheet.setRowHeight(rowIndex, 18);
      rowIndex++;

      final grandValues = [
        grandTotal,
        grandTepat,
        grandTerlambat,
        grandCuti,
        grandTidakHadir,
        grandIkutDoa,
        grandTidakDoa,
      ];
      final grandColors = [
        '#D6DBDF',
        '#D5F5E3',
        '#FDEBD0',
        '#D6EAF8',
        '#FADBD8',
        '#D5F5E3',
        '#FADBD8',
      ];
      final grandFonts = [
        '#1A252F',
        '#1E8449',
        '#784212',
        '#154360',
        '#7B241C',
        '#1E8449',
        '#7B241C',
      ];

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          )
          .cellStyle = makeStyle(
        bgColor: '#D6DBDF',
        bold: true,
        fontSize: 9,
        hAlign: ex.HorizontalAlign.Center,
      );

      for (int col = 0; col < grandValues.length; col++) {
        final cell = sheet.cell(
          ex.CellIndex.indexByColumnRow(
            columnIndex: col + 1,
            rowIndex: rowIndex,
          ),
        );
        cell.value = ex.IntCellValue(grandValues[col]);
        cell.cellStyle = makeStyle(
          bgColor: grandColors[col],
          fontColor: grandFonts[col],
          bold: true,
          fontSize: 13,
          hAlign: ex.HorizontalAlign.Center,
        );
      }
      // Col 8 (I): grand total lembur jam
      final gLemburJam = double.parse(
        (grandLemburMinutes / 60).toStringAsFixed(1),
      );
      final gValLembur = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
      );
      gValLembur.value = ex.DoubleCellValue(gLemburJam);
      gValLembur.cellStyle = makeStyle(
        bgColor: '#FCF3CF',
        fontColor: '#B9770E',
        bold: true,
        fontSize: 13,
        hAlign: ex.HorizontalAlign.Center,
      );

      sheet.setRowHeight(rowIndex, 26);
    }

    return excel.encode();
  }

  // ── Hitung status + doa + lembur per grup karyawan ───────────────────
  static Map<String, int> _countStatus(
    List<AdminAttendanceData> rows,
    Map<String, String>? doaMap,
  ) {
    int tepat = 0, terlambat = 0, cuti = 0, tidakHadir = 0;
    int ikutDoa = 0, tidakDoa = 0;
    int lemburMinutes = 0;

    for (final d in rows) {
      final s = d.displayStatus.toLowerCase();
      if (s.contains('tepat'))
        tepat++;
      else if (s.contains('terlambat'))
        terlambat++;
      else if (s.contains('cuti') || s.contains('dinas luar'))
        cuti++;
      else if (s.contains('tidak hadir') ||
          s.contains('absent') ||
          s.contains('tidak absen'))
        tidakHadir++;

      // Lembur (abaikan data tidak wajar > 24 jam)
      if (d.overtimeMinutes != null &&
          d.overtimeMinutes! > 0 &&
          d.overtimeMinutes! < 1440) {
        lemburMinutes += d.overtimeMinutes!;
      }

      // Hitung doa
      if (doaMap != null) {
        final tanggalKey =
            '${DateFormat('yyyy-MM-dd').format(d.attendanceDate)}_${d.userId.toLowerCase()}';
        final doaVal = doaMap[tanggalKey] ?? '';
        if (doaVal == 'ikut')
          ikutDoa++;
        else if (doaVal == 'tidak')
          tidakDoa++;
      }
    }

    return {
      'total': rows.length,
      'tepat': tepat,
      'terlambat': terlambat,
      'cuti': cuti,
      'tidakHadir': tidakHadir,
      'ikutDoa': ikutDoa,
      'tidakDoa': tidakDoa,
      'lemburMinutes': lemburMinutes,
    };
  }

  static ex.CellStyle _statusCellStyle(
    String status,
    String rowBg,
    String borderHex,
  ) {
    final s = status.toLowerCase();
    String fontColor, bgColor;
    if (s.contains('tepat')) {
      fontColor = '#1E8449';
      bgColor = '#D5F5E3';
    } else if (s.contains('sangat terlambat')) {
      fontColor = '#6E2C00';
      bgColor = '#FDEBD0';
    } else if (s.contains('terlambat')) {
      fontColor = '#784212';
      bgColor = '#FEF9E7';
    } else if (s.contains('dinas luar')) {
      fontColor = '#4A235A';
      bgColor = '#E8DAEF';
    } else if (s.contains('cuti')) {
      fontColor = '#154360';
      bgColor = '#D6EAF8';
    } else if (s.contains('tidak hadir') ||
        s.contains('absent') ||
        s.contains('tidak absen')) {
      fontColor = '#7B241C';
      bgColor = '#FADBD8';
    } else {
      fontColor = '#424949';
      bgColor = rowBg;
    }

    final b = ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );
    return ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString(bgColor),
      fontColorHex: ex.ExcelColor.fromHexString(fontColor),
      bold: true,
      fontSize: 10,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
      leftBorder: b,
      rightBorder: b,
      topBorder: b,
      bottomBorder: b,
    );
  }

  static ex.CellStyle _lemburCellStyle(
    int? ovtMinutes,
    String rowBg,
    String borderHex,
  ) {
    final has = ovtMinutes != null && ovtMinutes > 0 && ovtMinutes < 1440;
    final fontColor = has ? '#B9770E' : '#AEB6BF';
    final bgColor = has ? '#FEF9E7' : rowBg;

    final b = ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );
    return ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString(bgColor),
      fontColorHex: ex.ExcelColor.fromHexString(fontColor),
      bold: has,
      fontSize: 10,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
      leftBorder: b,
      rightBorder: b,
      topBorder: b,
      bottomBorder: b,
    );
  }

  static ex.CellStyle _doaCellStyle(
    String doa,
    String rowBg,
    String borderHex,
  ) {
    String fontColor, bgColor;
    if (doa == 'ikut') {
      fontColor = '#1E8449';
      bgColor = '#D5F5E3';
    } else if (doa == 'tidak') {
      fontColor = '#7B241C';
      bgColor = '#FADBD8';
    } else {
      fontColor = '#424949';
      bgColor = rowBg;
    }

    final b = ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );
    return ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString(bgColor),
      fontColorHex: ex.ExcelColor.fromHexString(fontColor),
      bold: doa.isNotEmpty,
      fontSize: 10,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
      leftBorder: b,
      rightBorder: b,
      topBorder: b,
      bottomBorder: b,
    );
  }

  static String _formatDate(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return date.toString().split(' ')[0];
    }
  }
}
