import 'package:excel/excel.dart' as ex;
import 'package:intl/intl.dart';
import '../../Screen admin/model/admin_attendance_model.dart';

class ExcelExportService {
  static List<int>? buildAbsensiExcel(
    List<AdminAttendanceData> data, {
    String? periodLabel,
  }) {
    final excel = ex.Excel.createExcel();
    const sheetName = 'Data Absensi';

    ex.Sheet sheet = excel[sheetName];
    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);

    // ── Warna ─────────────────────────────────────────
    const headerBg = '#1E3A5F';
    const subHeaderBg = '#2E86C1';
    const altRowBg = '#EBF5FB';
    const whiteBg = '#FFFFFF';
    const headerFg = '#FFFFFF';
    const borderHex = '#AED6F1';

    // ── Helper border ─────────────────────────────────
    ex.Border thinBorder() => ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.fromHexString(borderHex),
    );

    // ── Helper CellStyle ──────────────────────────────
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

    // ── BARIS 1: Judul ────────────────────────────────
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
      ex.CellIndex.indexByString('G1'),
    );

    // ── BARIS 2: Periode + tanggal cetak ─────────────
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
      ex.CellIndex.indexByString('D2'),
    );

    sheet.cell(ex.CellIndex.indexByString('E2')).value = ex.TextCellValue(
      printDate,
    );
    sheet.cell(ex.CellIndex.indexByString('E2')).cellStyle = subInfoStyle;
    sheet.merge(
      ex.CellIndex.indexByString('E2'),
      ex.CellIndex.indexByString('G2'),
    );

    // ── BARIS 3: Spacer ───────────────────────────────
    sheet.cell(ex.CellIndex.indexByString('A3')).value = ex.TextCellValue('');

    // ── BARIS 4: Header kolom ─────────────────────────
    const headers = [
      'No',
      'Nama Karyawan',
      'Departemen',
      'Tanggal',
      'Jam Masuk',
      'Jam Keluar',
      'Status',
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

    // ── BARIS 5+: Data ────────────────────────────────
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final rowBg = i % 2 == 0 ? whiteBg : altRowBg;
      final rowIndex = i + 4;

      final baseStyle = makeStyle(bgColor: rowBg);
      final centerStyle = makeStyle(
        bgColor: rowBg,
        hAlign: ex.HorizontalAlign.Center,
      );
      final statusStyle = _statusCellStyle(d.displayStatus, rowBg, borderHex);

      void setCell(int col, ex.CellValue value, ex.CellStyle style) {
        final cell = sheet.cell(
          ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
        );
        cell.value = value;
        cell.cellStyle = style;
      }

      setCell(0, ex.IntCellValue(i + 1), centerStyle);
      setCell(1, ex.TextCellValue(d.userName), baseStyle);
      setCell(2, ex.TextCellValue(d.department ?? '-'), baseStyle);
      setCell(3, ex.TextCellValue(_formatDate(d.attendanceDate)), centerStyle);
      setCell(4, ex.TextCellValue(d.formattedCheckIn), centerStyle);
      setCell(5, ex.TextCellValue(d.formattedCheckOut), centerStyle);
      setCell(6, ex.TextCellValue(d.displayStatus), statusStyle);
    }

    // ── FOOTER: Summary ───────────────────────────────
    final spacerRow = data.length + 5;
    final summaryRow = spacerRow + 1;

    sheet
        .cell(
          ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: spacerRow),
        )
        .value = ex.TextCellValue(
      '',
    );

    final summaryLabelStyle = makeStyle(
      bgColor: headerBg,
      fontColor: headerFg,
      bold: true,
      fontSize: 9,
      hAlign: ex.HorizontalAlign.Center,
    );
    final summaryValStyle = makeStyle(
      bgColor: altRowBg,
      bold: true,
      fontSize: 9,
      hAlign: ex.HorizontalAlign.Center,
    );

    final tepatWaktu = data
        .where((d) => d.displayStatus.toLowerCase().contains('tepat'))
        .length;
    final terlambat = data
        .where((d) => d.displayStatus.toLowerCase().contains('terlambat'))
        .length;
    final cuti = data
        .where((d) => d.displayStatus.toLowerCase().contains('cuti'))
        .length;
    final tidakHadir = data
        .where(
          (d) =>
              d.displayStatus.toLowerCase().contains('tidak hadir') ||
              d.displayStatus.toLowerCase().contains('absent'),
        )
        .length;

    final summaryLabels = [
      'Total Data',
      'Tepat Waktu',
      'Terlambat',
      'Cuti',
      'Tidak Hadir',
    ];
    final summaryValues = [
      data.length.toString(),
      tepatWaktu.toString(),
      terlambat.toString(),
      cuti.toString(),
      tidakHadir.toString(),
    ];

    for (int col = 0; col < summaryLabels.length; col++) {
      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(
              columnIndex: col + 1,
              rowIndex: summaryRow,
            ),
          )
          .value = ex.TextCellValue(
        summaryLabels[col],
      );
      sheet
              .cell(
                ex.CellIndex.indexByColumnRow(
                  columnIndex: col + 1,
                  rowIndex: summaryRow,
                ),
              )
              .cellStyle =
          summaryLabelStyle;

      sheet
          .cell(
            ex.CellIndex.indexByColumnRow(
              columnIndex: col + 1,
              rowIndex: summaryRow + 1,
            ),
          )
          .value = ex.TextCellValue(
        summaryValues[col],
      );
      sheet
              .cell(
                ex.CellIndex.indexByColumnRow(
                  columnIndex: col + 1,
                  rowIndex: summaryRow + 1,
                ),
              )
              .cellStyle =
          summaryValStyle;
    }

    // ── Lebar kolom ───────────────────────────────────
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 28);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 18);

    // ── Tinggi baris ──────────────────────────────────
    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 18);
    sheet.setRowHeight(3, 22);

    return excel.encode();
  }

  // ── Warna cell status ─────────────────────────────────
  static ex.CellStyle _statusCellStyle(
    String status,
    String rowBg,
    String borderHex,
  ) {
    String fontColor;
    String bgColor;

    final s = status.toLowerCase();
    if (s.contains('tepat')) {
      fontColor = '#1E8449';
      bgColor = '#D5F5E3';
    } else if (s.contains('terlambat')) {
      fontColor = '#784212';
      bgColor = '#FDEBD0';
    } else if (s.contains('cuti')) {
      fontColor = '#154360';
      bgColor = '#D6EAF8';
    } else if (s.contains('tidak hadir') || s.contains('absent')) {
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

  static String _formatDate(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return date.toString().split(' ')[0];
    }
  }
}
