// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:typed_data';

import 'package:excel/excel.dart' as ex;
import 'package:intl/intl.dart';

import '../../Screen admin/model/admin_attendance_model.dart';
import '../../Screen admin/model/overtimemodeladmin.dart';

class ExcelExportService {
  static Uint8List? buildAbsensiExcel(
    List<AdminAttendanceData> data, {
    String? periodLabel,
    Map<String, String>? doaMap,
    int totalHariKerja = 0,
    // Set tanggal 'yyyy-MM-dd' yang merupakan hari libur/tanggal merah
    // (weekend + event kalender tipe LIBUR). Dipakai untuk aturan minimum
    // lembur: absen di hari libur = minimal 4 jam, lembur di hari biasa
    // (kalau memang ada tercatat) = minimal 3 jam.
    Set<String>? liburDateKeys,
    // Pengajuan lembur yang sudah Approved (fitur Lembur), dipetakan ke
    // 'yyyy-MM-dd_userId' -> total jam. Kolom "Lembur" per baris & REKAP
    // Lembur Biasa/Libur HANYA menghitung hari yang ada di map ini —
    // karyawan tetap boleh absen di hari libur, tapi harus mengajukan
    // lembur & disetujui HRD supaya masuk rekap sebagai lembur.
    Map<String, double>? overtimeApprovedMap,
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

    // Tulis label+value REKAP dibungkus (wrap) mulai dari kolom B (kolom A
    // dibiarkan kosong — itu kolom "No" yang sempit, teks label/nama jadi
    // terpotong kalau dipaksa masuk situ). Kalau stat-nya lebih dari 7
    // (kolom C..I), sisanya lanjut ke pasangan baris berikutnya.
    // Mengembalikan row index berikutnya yang masih kosong.
    int writeWrappedRekap({
      required int startRow,
      required String cornerLabel,
      required String valueRowLabel,
      required List<String> labels,
      required List<dynamic> values,
      required List<String> valColors,
      required List<String> fontColors,
      required ex.CellStyle labelStyle,
      required ex.CellStyle rowLabelStyle,
      required int valueFontSize,
      required double valueRowHeight,
    }) {
      const chunkSize = 7; // kolom C..I
      var row = startRow;
      var idx = 0;
      var first = true;

      while (idx < labels.length) {
        final end = (idx + chunkSize < labels.length)
            ? idx + chunkSize
            : labels.length;

        setCell(col: 0, row: row, value: ex.TextCellValue(''), style: labelStyle);
        setCell(
          col: 1,
          row: row,
          value: ex.TextCellValue(first ? cornerLabel : ''),
          style: labelStyle,
        );
        for (int i = idx; i < end; i++) {
          setCell(
            col: i - idx + 2,
            row: row,
            value: ex.TextCellValue(labels[i]),
            style: labelStyle,
          );
        }
        sheet.setRowHeight(row, 18);
        row++;

        setCell(
          col: 0,
          row: row,
          value: ex.TextCellValue(''),
          style: rowLabelStyle,
        );
        setCell(
          col: 1,
          row: row,
          value: ex.TextCellValue(first ? valueRowLabel : ''),
          style: rowLabelStyle,
        );
        for (int i = idx; i < end; i++) {
          setDynamicCell(
            col: i - idx + 2,
            row: row,
            value: values[i],
            style: makeStyle(
              bgColor: valColors[i],
              fontColor: fontColors[i],
              bold: true,
              fontSize: valueFontSize,
              hAlign: ex.HorizontalAlign.Center,
            ),
          );
        }
        sheet.setRowHeight(row, valueRowHeight);
        row++;

        idx = end;
        first = false;
      }

      return row;
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

    sheet.merge(
      ex.CellIndex.indexByString('A1'),
      ex.CellIndex.indexByString('I1'),
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

    // ── Row 3: Spacer ───────────────────────────────────────────────
    sheet.cell(ex.CellIndex.indexByString('A3')).value = ex.TextCellValue('');

    // ── Header Data Utama — ditulis ulang di depan tiap karyawan ────
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

    void writeHeaderRow(int row) {
      for (int col = 0; col < headers.length; col++) {
        setCell(
          col: col,
          row: row,
          value: ex.TextCellValue(headers[col]),
          style: headerStyle,
        );
      }
      sheet.setRowHeight(row, 22);
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

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 18);

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
    int rowIndex = 3;

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
    int grandLemburHariBiasa = 0;
    int grandLemburHariLibur = 0;
    int grandJumlahHadir = 0;

    for (final entry in grouped.entries) {
      final rows = entry.value;

      // Header data diulang di depan tiap karyawan, dan No dimulai lagi
      // dari 1 — bukan lanjut dari nomor karyawan sebelumnya.
      writeHeaderRow(rowIndex);
      rowIndex++;
      int no = 1;

      for (int i = 0; i < rows.length; i++) {
        final d = rows[i];
        final rowBg = no % 2 == 1 ? whiteBg : altRowBg;
        final baseStyle = makeStyle(bgColor: rowBg);
        final centerStyle = makeStyle(
          bgColor: rowBg,
          hAlign: ex.HorizontalAlign.Center,
        );
        final tanggalKey =
            '${DateFormat('yyyy-MM-dd').format(d.attendanceDate)}_${d.userId.toLowerCase()}';
        final doaVal = doaMap?[tanggalKey] ?? '';
        final doaStyle = _doaCellStyle(doaVal, rowBg, borderHex);
        final submittedJam = overtimeApprovedMap?[tanggalKey];
        final ovtMin = submittedJam != null
            ? (submittedJam * 60).round()
            : null;
        final hasOvt = ovtMin != null && ovtMin > 0 && ovtMin < 1440;
        final statusAbsensi = d.displayStatus.trim();
        final excelStatus = hasOvt &&
                !statusAbsensi.toLowerCase().contains('lembur')
            ? (statusAbsensi.isEmpty
                  ? 'Lembur'
                  : '$statusAbsensi / Lembur')
            : d.displayStatus;
        final statusStyle = _statusCellStyle(excelStatus, rowBg, borderHex);
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
          value: ex.TextCellValue(excelStatus),
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

      final counts = _countStatus(
        rows,
        doaMap,
        liburDateKeys,
        overtimeApprovedMap,
      );
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
      grandLemburHariBiasa += counts['lemburHariBiasa']!;
      grandLemburHariLibur += counts['lemburHariLibur']!;
      grandJumlahHadir += counts['jumlahHadir']!;

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
          'Jumlah Hadir',
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
          'Lembur Biasa (Hari)',
          'Lembur Libur (Hari)',
        ];

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
          counts['jumlahHadir']!,
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
          counts['lemburHariBiasa']!,
          counts['lemburHariLibur']!,
        ];
        const summaryValColors = [
          '#EBF5FB',
          '#D5F5E3',
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
          '#FCF3CF',
          '#FDEBD0',
        ];
        const summaryFontColors = [
          '#1E3A5F',
          '#1E8449',
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
          '#B9770E',
          '#784212',
        ];

        rowIndex = writeWrappedRekap(
          startRow: rowIndex,
          cornerLabel: 'REKAP',
          valueRowLabel: rows[0].userName,
          labels: summaryLabels,
          values: summaryValues,
          valColors: summaryValColors,
          fontColors: summaryFontColors,
          labelStyle: summaryLabelStyle,
          rowLabelStyle: namaStyle,
          valueFontSize: 10,
          valueRowHeight: 22,
        );
        rowIndex++;
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
    final grandValueRowStyle = makeStyle(
      bgColor: '#D6DBDF',
      bold: true,
      fontSize: 9,
      hAlign: ex.HorizontalAlign.Center,
    );
    const grandLabels = [
      'Total Data',
      'Jumlah Hadir',
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
      'Lembur Biasa (Hari)',
      'Lembur Libur (Hari)',
    ];

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
      grandJumlahHadir,
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
      grandLemburHariBiasa,
      grandLemburHariLibur,
    ];
    const grandColors = [
      '#D6DBDF',
      '#D5F5E3',
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
      '#FCF3CF',
      '#FDEBD0',
    ];
    const grandFonts = [
      '#1A252F',
      '#1E8449',
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
      '#B9770E',
      '#784212',
    ];
    writeWrappedRekap(
      startRow: rowIndex,
      cornerLabel: isMultiHari ? 'GRAND TOTAL' : 'TOTAL',
      valueRowLabel: '',
      labels: grandLabels,
      values: grandValues,
      valColors: grandColors,
      fontColors: grandFonts,
      labelStyle: grandLabelStyle,
      rowLabelStyle: grandValueRowStyle,
      valueFontSize: 12,
      valueRowHeight: 26,
    );

    final encoded = excel.encode();

    if (encoded == null) {
      return null;
    }

    return Uint8List.fromList(encoded);
  }

  // ── Laporan Overtime — format sama seperti Laporan Absensi ─────
  static Uint8List? buildOvertimeExcel(
    List<AdminOvertimeData> data, {
    String? periodLabel,
    Map<String, String>? departmentByUserId,
  }) {
    final excel = ex.Excel.createExcel();
    const sheetName = 'Laporan Overtime';
    final ex.Sheet sheet = excel[sheetName];

    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);

    const headerBg = '#1E3A5F';
    const subHeaderBg = '#2E86C1';
    const altRowBg = '#EBF5FB';
    const whiteBg = '#FFFFFF';
    const headerFg = '#FFFFFF';
    const borderHex = '#AED6F1';

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

    // Sama seperti di buildAbsensiExcel — REKAP dibungkus mulai kolom B,
    // kolom A dibiarkan kosong (kolom "No" terlalu sempit untuk teks).
    int writeWrappedRekap({
      required int startRow,
      required String cornerLabel,
      required String valueRowLabel,
      required List<String> labels,
      required List<dynamic> values,
      required List<String> valColors,
      required List<String> fontColors,
      required ex.CellStyle labelStyle,
      required ex.CellStyle rowLabelStyle,
      required int valueFontSize,
      required double valueRowHeight,
    }) {
      const chunkSize = 7;
      var row = startRow;
      var idx = 0;
      var first = true;

      while (idx < labels.length) {
        final end = (idx + chunkSize < labels.length)
            ? idx + chunkSize
            : labels.length;

        setCell(
          col: 0,
          row: row,
          value: ex.TextCellValue(''),
          style: labelStyle,
        );
        setCell(
          col: 1,
          row: row,
          value: ex.TextCellValue(first ? cornerLabel : ''),
          style: labelStyle,
        );
        for (int i = idx; i < end; i++) {
          setCell(
            col: i - idx + 2,
            row: row,
            value: ex.TextCellValue(labels[i]),
            style: labelStyle,
          );
        }
        sheet.setRowHeight(row, 18);
        row++;

        setCell(
          col: 0,
          row: row,
          value: ex.TextCellValue(''),
          style: rowLabelStyle,
        );
        setCell(
          col: 1,
          row: row,
          value: ex.TextCellValue(first ? valueRowLabel : ''),
          style: rowLabelStyle,
        );
        for (int i = idx; i < end; i++) {
          setDynamicCell(
            col: i - idx + 2,
            row: row,
            value: values[i],
            style: makeStyle(
              bgColor: valColors[i],
              fontColor: fontColors[i],
              bold: true,
              fontSize: valueFontSize,
              hAlign: ex.HorizontalAlign.Center,
            ),
          );
        }
        sheet.setRowHeight(row, valueRowHeight);
        row++;

        idx = end;
        first = false;
      }

      return row;
    }

    // ── Row 1: Judul ──────────────────────────────────────────────
    sheet.cell(ex.CellIndex.indexByString('A1')).value = ex.TextCellValue(
      'LAPORAN OVERTIME HRD',
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

    // ── Row 2: Periode + Dicetak ─────────────────────────────────
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

    // ── Header data — ditulis ulang di depan tiap karyawan ──────
    const headers = [
      'No',
      'Nama Karyawan',
      'Departemen',
      'Tanggal',
      'Jam Mulai',
      'Jam Selesai',
      'Total Jam',
      'Status',
      'Catatan',
    ];

    final headerStyle = makeStyle(
      bgColor: subHeaderBg,
      fontColor: headerFg,
      bold: true,
      fontSize: 10,
      hAlign: ex.HorizontalAlign.Center,
    );

    void writeHeaderRow(int row) {
      for (int col = 0; col < headers.length; col++) {
        setCell(
          col: col,
          row: row,
          value: ex.TextCellValue(headers[col]),
          style: headerStyle,
        );
      }
      sheet.setRowHeight(row, 22);
    }

    // ── Lebar kolom ───────────────────────────────────────────────
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 28);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 10);
    sheet.setColumnWidth(5, 10);
    sheet.setColumnWidth(6, 10);
    sheet.setColumnWidth(7, 16);
    sheet.setColumnWidth(8, 26);

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 18);

    // ── Group per karyawan ────────────────────────────────────────
    final grouped = <String, List<AdminOvertimeData>>{};
    for (final d in data) {
      grouped.putIfAbsent(d.userId, () => []).add(d);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.tanggalOvertime.compareTo(b.tanggalOvertime));
    }

    int rowIndex = 3;
    int grandTotal = 0;
    int grandPending = 0;
    int grandApproved = 0;
    int grandRejected = 0;
    double grandJam = 0;

    for (final entry in grouped.entries) {
      final rows = entry.value;
      final dept = departmentByUserId?[entry.key] ?? '-';

      writeHeaderRow(rowIndex);
      rowIndex++;
      int no = 1;

      int pending = 0, approved = 0, rejected = 0;
      double totalJam = 0;

      for (final d in rows) {
        final rowBg = no % 2 == 1 ? whiteBg : altRowBg;
        final baseStyle = makeStyle(bgColor: rowBg);
        final centerStyle = makeStyle(
          bgColor: rowBg,
          hAlign: ex.HorizontalAlign.Center,
        );
        final statusStyle = _overtimeStatusCellStyle(
          d.status,
          rowBg,
          borderHex,
        );

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
          value: ex.TextCellValue(dept),
          style: baseStyle,
        );
        setCell(
          col: 3,
          row: rowIndex,
          value: ex.TextCellValue(d.formattedDate),
          style: centerStyle,
        );
        setCell(
          col: 4,
          row: rowIndex,
          value: ex.TextCellValue(d.formattedMulai),
          style: centerStyle,
        );
        setCell(
          col: 5,
          row: rowIndex,
          value: ex.TextCellValue(d.formattedSelesai),
          style: centerStyle,
        );
        setCell(
          col: 6,
          row: rowIndex,
          value: ex.TextCellValue('${d.totalJam.toStringAsFixed(1)} jam'),
          style: centerStyle,
        );
        setCell(
          col: 7,
          row: rowIndex,
          value: ex.TextCellValue(d.statusText),
          style: statusStyle,
        );
        setCell(
          col: 8,
          row: rowIndex,
          value: ex.TextCellValue(d.catatan ?? '-'),
          style: baseStyle,
        );
        rowIndex++;
        no++;

        totalJam += d.totalJam;
        switch (d.status.toLowerCase()) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }

      grandTotal += rows.length;
      grandPending += pending;
      grandApproved += approved;
      grandRejected += rejected;
      grandJam += totalJam;

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

      rowIndex = writeWrappedRekap(
        startRow: rowIndex,
        cornerLabel: 'REKAP',
        valueRowLabel: rows[0].userName,
        labels: const [
          'Total Pengajuan',
          'Pending',
          'Approved',
          'Rejected',
          'Total Jam',
        ],
        values: <dynamic>[
          rows.length,
          pending,
          approved,
          rejected,
          '${totalJam.toStringAsFixed(1)} jam',
        ],
        valColors: const [
          '#EBF5FB',
          '#FDEBD0',
          '#D5F5E3',
          '#FADBD8',
          '#FCF3CF',
        ],
        fontColors: const [
          '#1E3A5F',
          '#784212',
          '#1E8449',
          '#7B241C',
          '#B9770E',
        ],
        labelStyle: summaryLabelStyle,
        rowLabelStyle: namaStyle,
        valueFontSize: 10,
        valueRowHeight: 22,
      );
      rowIndex++;
    }

    // ── Grand Total ───────────────────────────────────────────────
    rowIndex++;
    final grandLabelStyle = makeStyle(
      bgColor: '#1A252F',
      fontColor: headerFg,
      bold: true,
      fontSize: 10,
      hAlign: ex.HorizontalAlign.Center,
    );
    final grandValueRowStyle = makeStyle(
      bgColor: '#D6DBDF',
      bold: true,
      fontSize: 9,
      hAlign: ex.HorizontalAlign.Center,
    );

    writeWrappedRekap(
      startRow: rowIndex,
      cornerLabel: grouped.length > 1 ? 'GRAND TOTAL' : 'TOTAL',
      valueRowLabel: '',
      labels: const [
        'Total Pengajuan',
        'Pending',
        'Approved',
        'Rejected',
        'Total Jam',
      ],
      values: <dynamic>[
        grandTotal,
        grandPending,
        grandApproved,
        grandRejected,
        '${grandJam.toStringAsFixed(1)} jam',
      ],
      valColors: const [
        '#D6DBDF',
        '#FDEBD0',
        '#D5F5E3',
        '#FADBD8',
        '#FCF3CF',
      ],
      fontColors: const [
        '#1A252F',
        '#784212',
        '#1E8449',
        '#7B241C',
        '#B9770E',
      ],
      labelStyle: grandLabelStyle,
      rowLabelStyle: grandValueRowStyle,
      valueFontSize: 12,
      valueRowHeight: 26,
    );

    final encoded = excel.encode();
    if (encoded == null) return null;
    return Uint8List.fromList(encoded);
  }

  static ex.CellStyle _overtimeStatusCellStyle(
    String status,
    String rowBg,
    String borderHex,
  ) {
    final s = status.toLowerCase();
    String bg = rowBg;
    String fg = '#000000';

    if (s == 'approved') {
      bg = '#D5F5E3';
      fg = '#1E8449';
    } else if (s == 'pending') {
      bg = '#FDEBD0';
      fg = '#784212';
    } else if (s == 'rejected') {
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

  // ── Hitung status detail + doa + lembur per karyawan ───────────
  // Lembur di REKAP export sekarang bersumber dari pengajuan lembur
  // (fitur Lembur) yang sudah Approved — BUKAN lagi dari kolom overtime
  // attendance mentah. Karyawan tetap boleh absen di hari libur/tanggal
  // merah, tapi supaya masuk rekap sebagai lembur, harus mengajukan
  // lembur dan disetujui HRD. Kalau disetujui: hari libur dihitung
  // minimal 4 jam, hari biasa minimal 3 jam (dibulatkan ke atas dari
  // jam yang diajukan).
  static const int _minLemburHariBiasaMenit = 180;
  static const int _minLemburHariLiburMenit = 240;

  static Map<String, int> _countStatus(
    List<AdminAttendanceData> rows,
    Map<String, String>? doaMap,
    Set<String>? liburDateKeys,
    Map<String, double>? overtimeApprovedMap,
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
    int lemburHariBiasa = 0;
    int lemburHariLibur = 0;
    int jumlahHadir = 0;

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

      // "Jumlah Hadir" di REKAP — dihitung terpisah dari kategori status
      // di atas (boleh tumpang tindih): Tepat Waktu, Terlambat, Absen
      // Luar Radius (disetujui), dan Izin Datang Terlambat/Izin Luar
      // Radius semuanya dianggap tetap hadir/masuk kerja.
      final isLuarRadius =
          status.contains('luar radius') ||
          checkIn.contains('luar radius') ||
          checkOut.contains('luar radius') ||
          notes.contains('luar radius');
      final isIzinTelat =
          status.contains('izin datang terlambat') ||
          status.contains('izin telat') ||
          checkIn.contains('izin datang terlambat') ||
          checkIn.contains('izin telat') ||
          notes.contains('izin datang terlambat') ||
          notes.contains('izin telat');
      if (isTepat || isTerlambat || isLuarRadius || isIzinTelat) {
        jumlahHadir++;
      }

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

      final tanggalOnly = DateFormat('yyyy-MM-dd').format(d.attendanceDate);
      final overtimeKey = '${tanggalOnly}_${d.userId.toLowerCase()}';
      final submittedJam = overtimeApprovedMap?[overtimeKey];
      final ovt = submittedJam != null ? (submittedJam * 60).round() : null;
      // Lembur di REKAP HANYA dihitung kalau ada pengajuan lembur resmi
      // yang sudah disetujui untuk tanggal itu — absen di hari libur
      // (atau lembur di hari biasa) tidak lagi otomatis dihitung tanpa
      // pengajuan.
      final hasOvtRecorded = ovt != null && ovt > 0;
      final isLiburDay = liburDateKeys?.contains(tanggalOnly) ?? false;

      if (isLiburDay) {
        // Absen + lembur diajukan & disetujui di hari libur/tanggal
        // merah = minimal 4 jam.
        if (hasOvtRecorded) {
          final effective = ovt > _minLemburHariLiburMenit
              ? ovt
              : _minLemburHariLiburMenit;
          lemburMinutes += effective;
          lemburHariLibur++;
        }
      } else if (hasOvtRecorded) {
        // Hari biasa: cuma dihitung kalau memang ada lembur diajukan &
        // disetujui, dibulatkan ke atas jadi minimal 3 jam.
        final effective = ovt > _minLemburHariBiasaMenit
            ? ovt
            : _minLemburHariBiasaMenit;
        lemburMinutes += effective;
        lemburHariBiasa++;
      }

      final tanggalKey =
          '${tanggalOnly}_${d.userId.toLowerCase()}';
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
      'lemburHariBiasa': lemburHariBiasa,
      'lemburHariLibur': lemburHariLibur,
      'jumlahHadir': jumlahHadir,
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
    } else if (s.contains('izin datang terlambat') ||
        s.contains('izin telat')) {
      // Izin Datang Terlambat sudah disetujui HRD — tetap dianggap hadir,
      // jadi warnanya hijau (sama seperti Tepat Waktu), bukan warna
      // "Terlambat" biasa yang menandakan masalah.
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
