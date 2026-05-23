import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:grader_tool/models/grading_result.dart';

class ExcelExportService {
  static Future<String?> exportToExcel(
    List<GradingResult> results,
    String markerName,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheetObject = excel['Sheet1'];

      var maxRequirements = 0;
      for (final res in results) {
        if (res.requirements.length > maxRequirements) {
          maxRequirements = res.requirements.length;
        }
      }

      final List<CellValue> header1 = [];
      header1.add(TextCellValue('Alias'));
      header1.add(TextCellValue('Marker'));
      for (var i = 1; i <= maxRequirements; i++) {
        header1.add(TextCellValue('Requirement $i (/100)'));
      }
      header1.add(TextCellValue('Total (/100)'));
      header1.add(TextCellValue('Total (/10)'));
      header1.add(TextCellValue('Comment'));
      sheetObject.appendRow(header1);

      final List<CellValue> header2 = [];
      header2.add(TextCellValue(''));
      header2.add(TextCellValue(''));
      for (var i = 1; i <= maxRequirements; i++) {
        header2.add(TextCellValue(''));
      }
      header2.add(TextCellValue(''));
      header2.add(TextCellValue(''));
      header2.add(TextCellValue(''));
      sheetObject.appendRow(header2);

      for (final res in results) {
        final alias = res.studentFile.replaceAll(RegExp(r'\.txt$'), '');
        final row = <CellValue>[TextCellValue(alias), TextCellValue(markerName)];

        for (var i = 0; i < maxRequirements; i++) {
          if (i < res.requirements.length) {
            row.add(DoubleCellValue(res.requirements[i].subtotalScore));
          } else {
            row.add(TextCellValue(''));
          }
        }

        row.add(DoubleCellValue(res.score));
        row.add(DoubleCellValue((res.score / 10).clamp(0, 10).toDouble()));

        final combinedComment = res.requirements
            .map((r) => '${r.requirementId}: ${r.requirementName} => ${r.subtotalScore.toStringAsFixed(1)}/${r.maxScore.toStringAsFixed(1)}')
            .join('\n');
        row.add(TextCellValue(combinedComment));

        sheetObject.appendRow(row);
      }

      final suggestedName = 'Grading_Results_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        confirmButtonText: 'Save Excel',
      );
      if (location == null) return null;

      final bytes = excel.save();
      if (bytes == null) return null;

      final file = File(location.path);
      await file.writeAsBytes(bytes);
      return location.path;
    } catch (_) {
      return null;
    }
  }
}
