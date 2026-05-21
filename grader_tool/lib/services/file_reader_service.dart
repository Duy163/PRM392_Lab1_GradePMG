import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

class FileReaderService {
  static Future<String> readDocxFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final documentEntry = archive.findFile('word/document.xml');
      if (documentEntry == null) {
        throw Exception('Invalid DOCX: word/document.xml not found');
      }

      final xml = utf8.decode(documentEntry.content as List<int>);
      final paragraphs = RegExp(r'<w:p[\s\S]*?</w:p>').allMatches(xml);
      final buffer = StringBuffer();

      if (paragraphs.isEmpty) {
        return _stripXmlText(xml);
      }

      for (final paragraph in paragraphs) {
        final text = _stripXmlText(paragraph.group(0) ?? '');
        if (text.trim().isNotEmpty) {
          buffer.writeln(text.trim());
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      throw Exception('Error reading grading criteria: $e');
    }
  }

  static String _stripXmlText(String xml) {
    final normalized = xml
        .replaceAll(RegExp(r'<w:tab\s*/>'), '\t')
        .replaceAll(RegExp(r'<w:br\s*/>'), '\n')
        .replaceAllMapped(
          RegExp(r'<w:t[^>]*>([\s\S]*?)</w:t>'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int extractQuestionCount(String criteriaText) {
    final matches = <int>{};

    for (final line in criteriaText.split(RegExp(r'\r?\n'))) {
      final normalized = line.trim();
      if (normalized.isEmpty) continue;

      final direct = RegExp(
        r'\b(?:question|q)\s*(\d+)\b',
        caseSensitive: false,
      ).firstMatch(normalized);
      if (direct != null) {
        matches.add(int.tryParse(direct.group(1) ?? '') ?? 0);
        continue;
      }

      final numbered = RegExp(r'^(\d+)\s*[).:-]').firstMatch(normalized);
      if (numbered != null) {
        matches.add(int.tryParse(numbered.group(1) ?? '') ?? 0);
      }
    }

    matches.remove(0);
    if (matches.isNotEmpty) {
      return matches.length;
    }

    final fallback = RegExp(
      r'^\s*[-*]?\s*(?:question|q)?\s*(\d+)\b',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(criteriaText);
    final fallbackNums = <int>{};
    for (final match in fallback) {
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > 0) {
        fallbackNums.add(value);
      }
    }

    return fallbackNums.isNotEmpty ? fallbackNums.length : 0;
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
