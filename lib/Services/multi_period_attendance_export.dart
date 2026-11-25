import 'dart:typed_data';

import 'package:excel/excel.dart' as ex;
import 'package:intl/intl.dart';

import '../Screen admin/service/admin_attendance_service.dart';

class AttendancePeriodCount {
  final HrdWorkPeriod period;
  final int workDays;
  final int present;
  final int sick;
  final int permit;
  final int absent;

  const AttendancePeriodCount(
    this.period,
    this.workDays,
    this.present,
    this.sick,
    this.permit,
    this.absent,
  );
}

class EmployeePeriodRecap {
  final String userId;
  final String name;
  final String department;
  final List<AttendancePeriodCount> periods;

  const EmployeePeriodRecap(
    this.userId,
    this.name,
    this.department,
    this.periods,
  );
}

class MultiPeriodAttendanceExport {
  static Uint8List? build(List<EmployeePeriodRecap> employees) {
    final workbook = ex.Excel.createExcel();
    final summary = workbook['Rekap Karyawan'];
    workbook.setDefaultSheet('Rekap Karyawan');
    final detail = workbook['Per Periode'];
    final heading = ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ex.ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: ex.HorizontalAlign.Center,
    );
    final alternate = ex.CellStyle(
      backgroundColorHex: ex.ExcelColor.fromHexString('#EBF5FB'),
    );
    void put(
      ex.Sheet sheet,
      int col,
      int row,
      ex.CellValue value, [
      ex.CellStyle? style,
    ]) {
      final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.value = value;
      if (style != null) cell.cellStyle = style;
    }

    final headers = [
      'No',
      'ID Karyawan',
      'Nama',
      'Departemen',
      'Jumlah Periode',
      'Hari Kerja',
      'Hadir',
      'Sakit',
      'Izin/Cuti',
      'Alpa',
      '% Hadir',
      '% Tidak Hadir',
      '% Sakit',
      '% Izin/Cuti',
      '% Alpa',
      'Rata-rata Hadir / Periode',
      'Penilaian',
    ];
    for (var i = 0; i < headers.length; i++) {
      put(summary, i, 0, ex.TextCellValue(headers[i]), heading);
      summary.setColumnWidth(i, i == 2 ? 28 : (i == 3 || i == 15 ? 24 : 17));
    }
    final detailHeaders = [
      'ID Karyawan',
      'Nama',
      'Departemen',
      'Periode',
      'Mulai',
      'Selesai',
      'Hari Kerja',
      'Hadir',
      'Sakit',
      'Izin/Cuti',
      'Alpa',
      '% Hadir',
    ];
    for (var i = 0; i < detailHeaders.length; i++) {
      put(detail, i, 0, ex.TextCellValue(detailHeaders[i]), heading);
      detail.setColumnWidth(i, i == 1 ? 28 : 17);
    }
    var detailRow = 1;
    for (var i = 0; i < employees.length; i++) {
      final employee = employees[i];
      final row = i + 1;
      final style = i.isOdd ? alternate : null;
      final work = employee.periods.fold<int>(0, (n, p) => n + p.workDays);
      final present = employee.periods.fold<int>(0, (n, p) => n + p.present);
      final sick = employee.periods.fold<int>(0, (n, p) => n + p.sick);
      final permit = employee.periods.fold<int>(0, (n, p) => n + p.permit);
      final absent = employee.periods.fold<int>(0, (n, p) => n + p.absent);
      final fraction = work == 0 ? 0.0 : present / work;
      final rating = fraction >= .98
          ? 'Sangat Baik'
          : fraction >= .95
          ? 'Baik'
          : fraction >= .90
          ? 'Cukup'
          : fraction >= .85
          ? 'Kurang'
          : 'Buruk';
      final values = <ex.CellValue>[
        ex.IntCellValue(i + 1),
        ex.TextCellValue(employee.userId),
        ex.TextCellValue(employee.name),
        ex.TextCellValue(employee.department),
        ex.IntCellValue(employee.periods.length),
        ex.IntCellValue(work),
        ex.IntCellValue(present),
        ex.IntCellValue(sick),
        ex.IntCellValue(permit),
        ex.IntCellValue(absent),
        ex.DoubleCellValue(fraction * 100),
        ex.DoubleCellValue(work == 0 ? 0 : (work - present) * 100 / work),
        ex.DoubleCellValue(work == 0 ? 0 : sick * 100 / work),
        ex.DoubleCellValue(work == 0 ? 0 : permit * 100 / work),
        ex.DoubleCellValue(work == 0 ? 0 : absent * 100 / work),
        ex.DoubleCellValue(
          employee.periods.isEmpty ? 0 : present / employee.periods.length,
        ),
        ex.TextCellValue(work == 0 ? 'Belum ada hari kerja' : rating),
      ];
      for (var col = 0; col < values.length; col++) {
        put(summary, col, row, values[col], style);
      }
      for (final p in employee.periods) {
        final d = detailRow++;
        final periodValues = <ex.CellValue>[
          ex.TextCellValue(employee.userId),
          ex.TextCellValue(employee.name),
          ex.TextCellValue(employee.department),
          ex.TextCellValue(p.period.bulanLabel),
          ex.TextCellValue(
            DateFormat('dd/MM/yyyy').format(p.period.tanggalMulai),
          ),
          ex.TextCellValue(
            DateFormat('dd/MM/yyyy').format(p.period.tanggalSelesai),
          ),
          ex.IntCellValue(p.workDays),
          ex.IntCellValue(p.present),
          ex.IntCellValue(p.sick),
          ex.IntCellValue(p.permit),
          ex.IntCellValue(p.absent),
          ex.DoubleCellValue(
            p.workDays == 0 ? 0 : p.present * 100 / p.workDays,
          ),
        ];
        for (var col = 0; col < periodValues.length; col++) {
          put(detail, col, d, periodValues[col], d.isOdd ? alternate : null);
        }
      }
    }
    summary.setColumnWidth(2, 30);
    detail.setColumnWidth(3, 22);
    final encoded = workbook.encode();
    return encoded == null ? null : Uint8List.fromList(encoded);
  }
}
