import 'dart:convert';
import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:grader_tool/models/rubric.dart';

class FileReaderService {
  static Future<String> readDocxFile(String filePath) async {
    try {
      if (filePath.toLowerCase().endsWith('.doc')) {
        throw Exception(
          'Tệp .doc (Word 97-2003) không được hỗ trợ trực tiếp. Vui lòng mở tệp trong Microsoft Word, chọn "Lưu dưới dạng" (Save As) và chọn định dạng "Word Document (.docx)", sau đó chọn lại tệp.',
        );
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final bytes = await file.readAsBytes();
      final text = docxToText(bytes, handleNumbering: true);
      return text.trim();
    } catch (e) {
      throw Exception('Error reading grading criteria: $e');
    }
  }

  static Future<RubricExam> readRubricJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      final content = await file.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return RubricExam.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Error reading rubric JSON: $e');
    }
  }

  static Future<String> readTxtFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      return file.readAsString();
    } catch (e) {
      throw Exception('Error reading student submission: $e');
    }
  }

  static Future<List<FileSystemEntity>> getStudentFiles(
    String folderPath,
  ) async {
    try {
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        throw Exception('Folder does not exist: $folderPath');
      }

      final files = folder
          .listSync()
          .where((file) => file.path.toLowerCase().endsWith('.txt'))
          .toList();

      files.sort((a, b) => a.path.compareTo(b.path));
      return files;
    } catch (e) {
      throw Exception('Error accessing student files: $e');
    }
  }

  static String getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }
}
