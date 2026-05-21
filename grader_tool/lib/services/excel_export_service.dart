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
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Determine max questions to create columns dynamically
      int maxQuestions = 0;
      for (var res in results) {
        if (res.questions.length > maxQuestions) {
          maxQuestions = res.questions.length;
        }
      }

      // Create Header Row 1
      List<CellValue> header1 = [
        TextCellValue('Alias'),
        TextCellValue('Marker'),
      ];
      for (int i = 1; i <= maxQuestions; i++) {
        header1.add(TextCellValue('Question $i'));
      }
      header1.add(TextCellValue('Total'));
      header1.add(TextCellValue('Comment'));
      sheetObject.appendRow(header1);

      // Create Header Row 2 (Empty for max scores)
      List<CellValue> header2 = [TextCellValue(''), TextCellValue('')];
      for (int i = 1; i <= maxQuestions; i++) {
        header2.add(TextCellValue(''));
      }
      header2.add(TextCellValue(''));
      header2.add(TextCellValue(''));
      sheetObject.appendRow(header2);

      // Add Data Rows
      for (var res in results) {
        // Use filename without extension as Alias
        String alias = res.studentFile.replaceAll(RegExp(r'\.txt$'), '');

        List<CellValue> row = [TextCellValue(alias), TextCellValue(markerName)];

        for (int i = 0; i < maxQuestions; i++) {
          if (i < res.questions.length) {
            row.add(DoubleCellValue(res.questions[i].score));
          } else {
            row.add(TextCellValue(''));
          }
        }

        row.add(DoubleCellValue(res.score));

        // Combine feedbacks for the Comment column
        String combinedComment = res.questions
            .map((q) => "Q${q.questionNumber}: ${q.feedback}")
            .join("\n");
        row.add(TextCellValue(combinedComment));

        sheetObject.appendRow(row);
      }

      final suggestedName =
          'Grading_Results_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        confirmButtonText: 'Save Excel',
      );
      if (location == null) {
        return null;
      }
      final savePath = location.path;

      final bytes = excel.save();
      if (bytes != null) {
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        return savePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
