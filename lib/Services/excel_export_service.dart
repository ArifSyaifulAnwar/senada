// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:typed_data';

import 'package:excel/excel.dart' as ex;
import 'package:intl/intl.dart';

import '../../Screen admin/model/admin_attendance_model.dart';

class ExcelExportService {
  static Uint8List? buildAbsensiExcel(
    List<AdminAttendanceData> data, {
    String? periodLabel,
    Map<String, String>? doaMap,
    int totalHariKerja = 0,
  }) {
    final excel = ex.Excel.createExcel();
    const sheetName = 'Data Absensi';
    final ex.Sheet sheet = excel[sheetName];

    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);

    // ── Warna ───────────────────────────────────────────────────────
    const headerBg = '#1E3A5F';
    const subHeaderBg = '#2E86C1';
    const altRowBg = '#EBF5FB';
    const whiteBg = '#FFFFFF';
    const headerFg = '#FFFFFF';
    const borderHex = '#AED6F1';

    // ── Helpers Style ───────────────────────────────────────────────
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
      final border = hasBorder
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
        leftBorder: border,
        rightBorder: border,
        topBorder: border,
        bottomBorder: border,
      );
    }

    void setCell({
      required int col,
      required int row,
      required ex.CellValue value,
      required ex.CellStyle style,
    }) {
      final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );

      cell.value = value;
      cell.cellStyle = style;
    }

    void setDynamicCell({
      required int col,
      required int row,
      required dynamic value,
      required ex.CellStyle style,
    }) {
      final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );

      if (value is int) {
        cell.value = ex.IntCellValue(value);
      } else if (value is double) {
        cell.value = ex.DoubleCellValue(value);
      } else {
        cell.value = ex.TextCellValue(value?.toString() ?? '');
      }

      cell.cellStyle = style;
    }

    // ── Row 1: Judul ────────────────────────────────────────────────
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

    // Dibuat sampai K karena summary punya kolom tambahan.
    sheet.merge(
      ex.CellIndex.indexByString('A1'),
      ex.CellIndex.indexByString('N1'),
    );

    // ── Row 2: Periode + Dicetak ───────────────────────────────────
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
      ex.CellIndex.indexByString('G2'),
    );

    sheet.cell(ex.CellIndex.indexByString('H2')).value = ex.TextCellValue(
      printDate,
    );
    sheet.cell(ex.CellIndex.indexByString('H2')).cellStyle = subInfoStyle;
    sheet.merge(
      ex.CellIndex.indexByString('H2'),
      ex.CellIndex.indexByString('N2'),
    );

    // ── Row 3: Spacer ───────────────────────────────────────────────
    sheet.cell(ex.CellIndex.indexByString('A3')).value = ex.TextCellValue('');

    // ── Row 4: Header Data Utama ───────────────────────────────────
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
      setCell(
        col: col,
        row: 3,
        value: ex.TextCellValue(headers[col]),
        style: headerStyle,
      );
    }

    // ── Lebar kolom ────────────────────────────────────────────────
    sheet.setColumnWidth(0, 6); // No
    sheet.setColumnWidth(1, 30); // Nama
    sheet.setColumnWidth(2, 20); // Dept
    sheet.setColumnWidth(3, 16); // Tanggal
    sheet.setColumnWidth(4, 12); // Jam Masuk
    sheet.setColumnWidth(5, 12); // Jam Keluar
    sheet.setColumnWidth(6, 12); // Lembur
    sheet.setColumnWidth(7, 24); // Status
    sheet.setColumnWidth(8, 12); // Doa
    sheet.setColumnWidth(9, 16); // Persentase
    sheet.setColumnWidth(10, 16); // Cuti Tahunan / Persentase
    sheet.setColumnWidth(11, 14); // Izin Sakit / Doa
    sheet.setColumnWidth(12, 14); // Izin Lainnya / Doa
    sheet.setColumnWidth(13, 14); // Dinas Luar / Lembur summary

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 18);
    sheet.setRowHeight(3, 22);

    // ── Group per karyawan ─────────────────────────────────────────
    final grouped = <String, List<AdminAttendanceData>>{};

    for (final d in data) {
      grouped.putIfAbsent(d.userId, () => []).add(d);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.attendanceDate.compareTo(b.attendanceDate));
    }

    final maxPerKaryawan = grouped.values
        .map((v) => v.length)
        .fold(0, (a, b) => a > b ? a : b);

    final isMultiHari = maxPerKaryawan > 1;

    // ── Tulis data ─────────────────────────────────────────────────
    int rowIndex = 4;
    int no = 1;

    int grandTotal = 0;
    int grandTepat = 0;
    int grandTerlambat = 0;
    int grandCutiTahunan = 0;
    int grandIzinSakit = 0;
    int grandIzinLainnya = 0;
    int grandDinasLuar = 0;
    int grandTidakHadir = 0;
    int grandIkutDoa = 0;
    int grandTidakDoa = 0;
    int grandLemburMinutes = 0;

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
        final ovtMin = d.overtimeMinutes;
        final hasOvt = ovtMin != null && ovtMin > 0 && ovtMin < 1440;
        final lemburText = hasOvt
            ? '${(ovtMin / 60).toStringAsFixed(1)} jam'
            : '-';
        final lemburStyle = _lemburCellStyle(ovtMin, rowBg, borderHex);

        setCell(
          col: 0,
          row: rowIndex,
          value: ex.IntCellValue(no),
          style: centerStyle,
        );
        setCell(
          col: 1,
          row: rowIndex,
          value: ex.TextCellValue(d.userName),
          style: baseStyle,
        );
        setCell(
          col: 2,
          row: rowIndex,
          value: ex.TextCellValue(d.department ?? '-'),
          style: baseStyle,
        );
        setCell(
          col: 3,
          row: rowIndex,
          value: ex.TextCellValue(_formatDate(d.attendanceDate)),
          style: centerStyle,
        );
        setCell(
          col: 4,
          row: rowIndex,
          value: ex.TextCellValue(d.formattedCheckIn),
          style: centerStyle,
        );
        setCell(
          col: 5,
          row: rowIndex,
          value: ex.TextCellValue(d.formattedCheckOut),
          style: centerStyle,
        );
        setCell(
          col: 6,
          row: rowIndex,
          value: ex.TextCellValue(lemburText),
          style: lemburStyle,
        );
        setCell(
          col: 7,
          row: rowIndex,
          value: ex.TextCellValue(d.displayStatus),
          style: statusStyle,
        );
        setCell(
          col: 8,
          row: rowIndex,
          value: ex.TextCellValue(doaVal),
          style: doaStyle,
        );
        rowIndex++;
        no++;
      }

      final counts = _countStatus(rows, doaMap);
      grandTotal += counts['total']!;
      grandTepat += counts['tepat']!;
      grandTerlambat += counts['terlambat']!;
      grandCutiTahunan += counts['cutiTahunan']!;
      grandIzinSakit += counts['izinSakit']!;
      grandIzinLainnya += counts['izinLainnya']!;
      grandDinasLuar += counts['dinasLuar']!;
      grandTidakHadir += counts['tidakHadir']!;
      grandIkutDoa += counts['ikutDoa']!;
      grandTidakDoa += counts['tidakDoa']!;
      grandLemburMinutes += counts['lemburMinutes']!;

      if (isMultiHari) {
        rowIndex++;
        final summaryLabelStyle = makeStyle(
          bgColor: headerBg,
          fontColor: headerFg,
          bold: true,
          fontSize: 9,
          hAlign: ex.HorizontalAlign.Center,
        );
        final namaStyle = makeStyle(
          bgColor: '#F2F3F4',
          bold: true,
          fontSize: 9,
          hAlign: ex.HorizontalAlign.Center,
        );

        const summaryLabels = [
          'Total Data',
          'Hari Kerja',
          'Tepat Waktu',
          'Terlambat',
          'Cuti Tahunan',
          'Izin Sakit',
          'Izin Lainnya',
          'Dinas Luar',
          'Tidak Hadir',
          'Persentase',
          'Ikut Doa',
          'Tidak Doa',
          'Lembur (jam)',
        ];

        setCell(
          col: 0,
          row: rowIndex,
          value: ex.TextCellValue('REKAP'),
          style: summaryLabelStyle,
        );
        for (int col = 0; col < summaryLabels.length; col++) {
          setCell(
            col: col + 1,
            row: rowIndex,
            value: ex.TextCellValue(summaryLabels[col]),
            style: summaryLabelStyle,
          );
        }
        sheet.setRowHeight(rowIndex, 18);
        rowIndex++;

        // ((Tepat Waktu + Dinas Luar) - (Terlambat + Cuti + Izin + Tidak Hadir)) / Hari Kerja x 100%
        final nilaiKehadiran =
            counts['tepat']! +
            counts['dinasLuar']! -
            counts['terlambat']! -
            counts['cutiTahunan']! -
            counts['izinSakit']! -
            counts['izinLainnya']! -
            counts['tidakHadir']!;
        final persenKehadiran = totalHariKerja > 0
            ? (nilaiKehadiran / totalHariKerja) * 100
            : 0.0;

        final summaryValues = <dynamic>[
          counts['total']!,
          totalHariKerja,
          counts['tepat']!,
          counts['terlambat']!,
          counts['cutiTahunan']!,
          counts['izinSakit']!,
          counts['izinLainnya']!,
          counts['dinasLuar']!,
          counts['tidakHadir']!,
          '${persenKehadiran.toStringAsFixed(1)}%',
          counts['ikutDoa']!,
          counts['tidakDoa']!,
          (counts['lemburMinutes']! / 60).toStringAsFixed(1),
        ];
        const summaryValColors = [
          '#EBF5FB',
          '#EBF5FB',
          '#D5F5E3',
          '#FDEBD0',
          '#D6EAF8',
          '#F5EEF8',
          '#FDEDEC',
          '#E8F8F5',
          '#FADBD8',
          '#D5F5E3',
          '#D5F5E3',
          '#FADBD8',
          '#FCF3CF',
        ];
        const summaryFontColors = [
          '#1E3A5F',
          '#1E3A5F',
          '#1E8449',
          '#784212',
          '#154360',
          '#6C3483',
          '#922B21',
          '#117864',
          '#7B241C',
          '#1E8449',
          '#1E8449',
          '#7B241C',
          '#B9770E',
        ];

        setCell(
          col: 0,
          row: rowIndex,
          value: ex.TextCellValue(rows[0].userName),
          style: namaStyle,
        );
        for (int col = 0; col < summaryValues.length; col++) {
          setDynamicCell(
            col: col + 1,
            row: rowIndex,
            value: summaryValues[col],
            style: makeStyle(
              bgColor: summaryValColors[col],
              fontColor: summaryFontColors[col],
              bold: true,
              fontSize: 10,
              hAlign: ex.HorizontalAlign.Center,
            ),
          );
        }
        sheet.setRowHeight(rowIndex, 22);
        rowIndex += 2;
      }
    }

    // ── Grand Total ─────────────────────────────────────────────────
    rowIndex++;
    final grandLabelStyle = makeStyle(
      bgColor: '#1A252F',
      fontColor: headerFg,
      bold: true,
      fontSize: 10,
      hAlign: ex.HorizontalAlign.Center,
    );
    const grandLabels = [
      'Total Data',
      'Hari Kerja',
      'Tepat Waktu',
      'Terlambat',
      'Cuti Tahunan',
      'Izin Sakit',
      'Izin Lainnya',
      'Dinas Luar',
      'Tidak Hadir',
      'Persentase',
      'Ikut Doa',
      'Tidak Doa',
      'Lembur (jam)',
    ];
    setCell(
      col: 0,
      row: rowIndex,
      value: ex.TextCellValue(isMultiHari ? 'GRAND TOTAL' : 'TOTAL'),
      style: grandLabelStyle,
    );
    for (int col = 0; col < grandLabels.length; col++) {
      setCell(
        col: col + 1,
        row: rowIndex,
        value: ex.TextCellValue(grandLabels[col]),
        style: grandLabelStyle,
      );
    }
    sheet.setRowHeight(rowIndex, 18);
    rowIndex++;

    final totalKaryawan = grouped.length;
    final totalHariKerjaGrand = totalHariKerja * totalKaryawan;
    final grandNilaiKehadiran =
        grandTepat +
        grandDinasLuar -
        grandTerlambat -
        grandCutiTahunan -
        grandIzinSakit -
        grandIzinLainnya -
        grandTidakHadir;
    final grandPersenKehadiran = totalHariKerjaGrand > 0
        ? (grandNilaiKehadiran / totalHariKerjaGrand) * 100
        : 0.0;
    final grandValues = <dynamic>[
      grandTotal,
      totalHariKerjaGrand,
      grandTepat,
      grandTerlambat,
      grandCutiTahunan,
      grandIzinSakit,
      grandIzinLainnya,
      grandDinasLuar,
      grandTidakHadir,
      '${grandPersenKehadiran.toStringAsFixed(1)}%',
      grandIkutDoa,
      grandTidakDoa,
      (grandLemburMinutes / 60).toStringAsFixed(1),
    ];
    const grandColors = [
      '#D6DBDF',
      '#D6DBDF',
      '#D5F5E3',
      '#FDEBD0',
      '#D6EAF8',
      '#F5EEF8',
      '#FDEDEC',
      '#E8F8F5',
      '#FADBD8',
      '#D5F5E3',
      '#D5F5E3',
      '#FADBD8',
      '#FCF3CF',
    ];
    const grandFonts = [
      '#1A252F',
      '#1A252F',
      '#1E8449',
      '#784212',
      '#154360',
      '#6C3483',
      '#922B21',
      '#117864',
      '#7B241C',
      '#1E8449',
      '#1E8449',
      '#7B241C',
      '#B9770E',
    ];
    setCell(
      col: 0,
      row: rowIndex,
      value: ex.TextCellValue(''),
      style: makeStyle(
        bgColor: '#D6DBDF',
        bold: true,
        fontSize: 9,
        hAlign: ex.HorizontalAlign.Center,
      ),
    );
    for (int col = 0; col < grandValues.length; col++) {
      setDynamicCell(
        col: col + 1,
        row: rowIndex,
        value: grandValues[col],
        style: makeStyle(
          bgColor: grandColors[col],
          fontColor: grandFonts[col],
          bold: true,
          fontSize: 12,
          hAlign: ex.HorizontalAlign.Center,
        ),
      );
    }
    sheet.setRowHeight(rowIndex, 26);

    final encoded = excel.encode();

    if (encoded == null) {
      return null;
    }

    return Uint8List.fromList(encoded);
  }

  // ── Hitung status detail + doa + lembur per karyawan ───────────
  static Map<String, int> _countStatus(
    List<AdminAttendanceData> rows,
    Map<String, String>? doaMap,
  ) {
    int tepat = 0;
    int terlambat = 0;
    int cutiTahunan = 0;
    int izinSakit = 0;
    int izinLainnya = 0;
    int dinasLuar = 0;
    int tidakHadir = 0;
    int ikutDoa = 0;
    int tidakDoa = 0;
    int lemburMinutes = 0;

    for (final d in rows) {
      final status = d.displayStatus.toLowerCase();
      final checkIn = d.checkInStatus.toLowerCase();
      final checkOut = d.checkOutStatus.toLowerCase();
      final notes = d.notes.toLowerCase();

      final isDinasLuar =
          status.contains('dinas luar') ||
          checkIn.contains('dinas luar') ||
          checkOut.contains('dinas luar') ||
          notes.contains('dinas luar') ||
          checkIn.trim() == 'dl';
      final isCutiTahunan =
          status.contains('cuti tahunan') ||
          status == 'cuti' ||
          checkIn.contains('cuti tahunan') ||
          checkIn.contains('izin tahunan') ||
          notes.contains('cuti tahunan') ||
          notes.contains('izin tahunan');
      final isIzinSakit =
          status.contains('izin sakit') ||
          status == 'sakit' ||
          checkIn.contains('izin sakit') ||
          checkIn == 'sakit' ||
          notes.contains('izin sakit') ||
          notes.contains('sakit');
      final isTidakHadir =
          status.contains('tidak hadir') ||
          status.contains('tidak absen') ||
          status.contains('absent') ||
          status.contains('alpha') ||
          checkIn.contains('tidak hadir') ||
          checkIn.contains('tidak absen') ||
          checkIn.contains('absent');
      final isTerlambat =
          status.contains('terlambat') ||
          checkIn.contains('late') ||
          checkIn.contains('very_late');
      final isTepat = status.contains('tepat') || checkIn.contains('on_time');
      final isIzinLainnya =
          !isDinasLuar &&
          !isCutiTahunan &&
          !isIzinSakit &&
          (status.startsWith('izin') ||
              status.contains('umrah') ||
              status.contains('haji') ||
              status.contains('lahiran') ||
              status.contains('meninggal') ||
              checkIn.contains('izin') ||
              checkIn.contains('umrah') ||
              checkIn.contains('haji') ||
              checkIn.contains('lahiran') ||
              checkIn.contains('meninggal') ||
              notes.contains('izin') ||
              notes.contains('umrah') ||
              notes.contains('haji') ||
              notes.contains('lahiran') ||
              notes.contains('meninggal'));

      // Satu baris hanya boleh masuk satu kategori.
      if (isDinasLuar) {
        dinasLuar++;
      } else if (isCutiTahunan) {
        cutiTahunan++;
      } else if (isIzinSakit) {
        izinSakit++;
      } else if (isIzinLainnya) {
        izinLainnya++;
      } else if (isTidakHadir) {
        tidakHadir++;
      } else if (isTerlambat) {
        terlambat++;
      } else if (isTepat) {
        tepat++;
      }

      final ovt = d.overtimeMinutes;
      if (ovt != null && ovt > 0 && ovt < 1440) lemburMinutes += ovt;

      final tanggalKey =
          '${DateFormat('yyyy-MM-dd').format(d.attendanceDate)}_${d.userId.toLowerCase()}';
      final doaVal = doaMap?[tanggalKey]?.toLowerCase() ?? '';
      if (doaVal == 'ikut') ikutDoa++;
      if (doaVal == 'tidak') tidakDoa++;
    }

    return {
      'total': rows.length,
      'tepat': tepat,
      'terlambat': terlambat,
      'cutiTahunan': cutiTahunan,
      'izinSakit': izinSakit,
      'izinLainnya': izinLainnya,
      'dinasLuar': dinasLuar,
      'tidakHadir': tidakHadir,
      'ikutDoa': ikutDoa,
      'tidakDoa': tidakDoa,
      'lemburMinutes': lemburMinutes,
    };
  }

  static String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  static ex.CellStyle _statusCellStyle(
    String status,
    String rowBg,
    String borderHex,
  ) {
    final s = status.toLowerCase();

    String bg = rowBg;
    String fg = '#000000';

    if (s.contains('tepat')) {
      bg = '#D5F5E3';
      fg = '#1E8449';
    } else if (s.contains('terlambat')) {
      bg = '#FDEBD0';
      fg = '#784212';
    } else if (s.contains('cuti') ||
        s.contains('izin') ||
        s.contains('sakit') ||
        s.contains('dinas') ||
        s.contains('timeoff') ||
        s.contains('leave')) {
      bg = '#D6EAF8';
      fg = '#154360';
    } else if (s.contains('tidak hadir') ||
        s.contains('tidak absen') ||
        s.contains('absent')) {
      bg = '#FADBD8';
      fg = '#7B241C';
    }

    final border = ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );

    return ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString(bg),
      fontColorHex: ex.ExcelColor.fromHexString(fg),
      bold: true,
      fontSize: 10,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
  }

  static ex.CellStyle _doaCellStyle(
    String doa,
    String rowBg,
    String borderHex,
  ) {
    final d = doa.toLowerCase();

    String bg = rowBg;
    String fg = '#000000';

    if (d == 'ikut') {
      bg = '#D5F5E3';
      fg = '#1E8449';
    } else if (d == 'tidak') {
      bg = '#FADBD8';
      fg = '#7B241C';
    }

    final border = ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );

    return ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString(bg),
      fontColorHex: ex.ExcelColor.fromHexString(fg),
      bold: d.isNotEmpty,
      fontSize: 10,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
  }

  static ex.CellStyle _lemburCellStyle(
    int? overtimeMinutes,
    String rowBg,
    String borderHex,
  ) {
    final hasLembur =
        overtimeMinutes != null &&
        overtimeMinutes > 0 &&
        overtimeMinutes < 1440;

    final bg = hasLembur ? '#FCF3CF' : rowBg;
    final fg = hasLembur ? '#B9770E' : '#000000';

    final border = ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );

    return ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString(bg),
      fontColorHex: ex.ExcelColor.fromHexString(fg),
      bold: hasLembur,
      fontSize: 10,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
  }
}
