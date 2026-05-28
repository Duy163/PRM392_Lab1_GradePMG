import 'dart:convert';
import 'dart:io';
import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/models/rubric.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class ResultStorageService {
  static const String resultFolderName = 'result';

  /// Lưu kết quả chấm điểm vào file JSON trong folder result
  /// Bao gồm cả thông tin rubric và kết quả chi tiết
  static Future<String> saveGradingResult({
    required GradingResult result,
    required RubricExam rubric,
    String? customFileName,
  }) async {
    // Tạo folder result nếu chưa có
    final resultDir = Directory(resultFolderName);
    if (!await resultDir.exists()) {
      await resultDir.create(recursive: true);
    }

    // Tạo tên file với timestamp
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final studentName = result.studentFile
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final fileName = customFileName ?? '${studentName}_$timestamp.json';
    final filePath = '${resultDir.path}${Platform.pathSeparator}$fileName';

    // Tạo cấu trúc JSON đầy đủ
    final jsonData = {
      'metadata': {
        'graded_at': DateTime.now().toIso8601String(),
        'student_file': result.studentFile,
        'rubric_course': rubric.course,
        'rubric_title': rubric.title,
        'total_possible_points': rubric.totalPoints,
      },
      'rubric': _rubricToJson(rubric),
      'grading_result': _gradingResultToJson(result),
      'summary': {
        'total_score': result.score,
        'percentage': (result.score / rubric.totalPoints * 100).toStringAsFixed(
          2,
        ),
        'requirements_count': result.requirements.length,
        'general_feedback': result.feedback,
      },
    };

    // Ghi file
    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonData),
    );

    return filePath;
  }

  /// Lưu nhiều kết quả chấm điểm cùng lúc
  static Future<List<String>> saveMultipleResults({
    required List<GradingResult> results,
    required RubricExam rubric,
  }) async {
    final savedPaths = <String>[];

    for (final result in results) {
      try {
        final path = await saveGradingResult(result: result, rubric: rubric);
        savedPaths.add(path);
      } catch (e) {
        debugPrint('Error saving result for ${result.studentFile}: $e');
      }
    }

    return savedPaths;
  }

  /// Cập nhật file kết quả đã lưu theo student file sau khi chỉnh điểm tay.
  /// Hàm này giữ nguyên rubric/metadata gốc, chỉ ghi đè phần grading_result và summary.
  static Future<bool> updateSavedResultForStudent({
    required GradingResult result,
  }) async {
    final files = await getAllResultFiles();

    for (final file in files) {
      final data = await loadResultFromFile(file.path);
      final metadataStudentFile = data?['metadata']?['student_file'];
      final gradingStudentFile = data?['grading_result']?['student_file'];

      if (metadataStudentFile == result.studentFile ||
          gradingStudentFile == result.studentFile) {
        final updatedJson = Map<String, dynamic>.from(data ?? {});
        final metadata = Map<String, dynamic>.from(
          updatedJson['metadata'] as Map? ?? const {},
        );
        final rubric = Map<String, dynamic>.from(
          updatedJson['rubric'] as Map? ?? const {},
        );

        metadata['graded_at'] = DateTime.now().toIso8601String();
        metadata['student_file'] = result.studentFile;

        updatedJson['metadata'] = metadata;
        updatedJson['rubric'] = rubric;
        updatedJson['grading_result'] = _gradingResultToJson(result);
        updatedJson['summary'] = {
          'total_score': result.score,
          'percentage': metadata['total_possible_points'] is num &&
                  (metadata['total_possible_points'] as num).toDouble() > 0
              ? (result.score /
                      (metadata['total_possible_points'] as num).toDouble() *
                      100)
                  .toStringAsFixed(2)
              : '0.00',
          'requirements_count': result.requirements.length,
          'general_feedback': result.feedback,
        };

        await File(file.path).writeAsString(
          const JsonEncoder.withIndent('  ').convert(updatedJson),
        );
        _resultCache[file.path] = updatedJson;
        _fileSizeCache[file.path] = await File(file.path).length();
        return true;
      }
    }

    return false;
  }

  /// Lấy danh sách tất cả file kết quả trong folder result (OPTIMIZED - async operations)
  static Future<List<FileSystemEntity>> getAllResultFiles() async {
    final resultDir = Directory(resultFolderName);
    if (!await resultDir.exists()) {
      return [];
    }

    // Use async list() instead of sync listSync()
    final files = await resultDir
        .list()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList();

    // Sắp xếp theo thời gian modified (mới nhất trước) - async stat()
    final filesWithStats = await Future.wait(
      files.map((file) async {
        final stat = await file.stat();
        return {'file': file, 'modified': stat.modified};
      }),
    );

    filesWithStats.sort(
      (a, b) =>
          (b['modified'] as DateTime).compareTo(a['modified'] as DateTime),
    );

    return filesWithStats
        .map((item) => item['file'] as FileSystemEntity)
        .toList();
  }

  /// Xóa các file kết quả cũ hơn số ngày chỉ định (OPTIMIZED - async stat)
  static Future<int> deleteOldResults({required int olderThanDays}) async {
    final resultDir = Directory(resultFolderName);
    if (!await resultDir.exists()) {
      return 0;
    }

    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    int deletedCount = 0;

    final files = await getAllResultFiles();
    for (final file in files) {
      final stat = await file.stat(); // Use async stat()
      if (stat.modified.isBefore(cutoffDate)) {
        try {
          await file.delete();
          deletedCount++;
          debugPrint('Deleted old result: ${file.path}');
        } catch (e) {
          debugPrint('Error deleting ${file.path}: $e');
        }
      }
    }

    return deletedCount;
  }

  /// Xóa một file kết quả cụ thể
  static Future<bool> deleteResultFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting file $filePath: $e');
      return false;
    }
  }

  // Cache for parsed JSON results to avoid re-parsing
  static final Map<String, Map<String, dynamic>> _resultCache = {};
  static final Map<String, int> _fileSizeCache = {};

  /// Đọc lại kết quả từ file JSON (OPTIMIZED - with caching)
  static Future<Map<String, dynamic>?> loadResultFromFile(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      // Check cache validity
      final stat = await file.stat();
      final currentSize = stat.size;
      final cachedSize = _fileSizeCache[filePath];

      if (_resultCache.containsKey(filePath) && cachedSize == currentSize) {
        // Return cached result if file hasn't changed
        return _resultCache[filePath];
      }

      // Read and parse file
      final content = await file.readAsString();
      final result = jsonDecode(content) as Map<String, dynamic>;

      // Update cache
      _resultCache[filePath] = result;
      _fileSizeCache[filePath] = currentSize;

      return result;
    } catch (e) {
      debugPrint('Error loading result from $filePath: $e');
      return null;
    }
  }

  /// Clear cache (call when needed to free memory)
  static void clearCache() {
    _resultCache.clear();
    _fileSizeCache.clear();
  }

  // Helper methods để convert models sang JSON

  static Map<String, dynamic> _rubricToJson(RubricExam rubric) {
    return {
      'exam': {
        'course': rubric.course,
        'title': rubric.title,
        'total_points': rubric.totalPoints,
        'grading_scale_note': rubric.gradingScaleNote,
      },
      'requirements': rubric.requirements
          .map(
            (req) => {
              'id': req.id,
              'name': req.name,
              'max_points': req.maxPoints,
              'criteria': req.criteria
                  .map(
                    (crit) => {
                      'id': crit.id,
                      'name': crit.name,
                      'max_points': crit.maxPoints,
                      'levels': crit.levels.map(
                        (key, level) => MapEntry(key, {
                          'score_range': level.scoreRange,
                          'description': level.description,
                        }),
                      ),
                    },
                  )
                  .toList(),
              'common_mistakes': req.commonMistakes,
            },
          )
          .toList(),
    };
  }

  static Map<String, dynamic> _gradingResultToJson(GradingResult result) {
    return {
      'student_file': result.studentFile,
      'submission_content': result.submissionContent,
      'total_score': result.score,
      'general_feedback': result.feedback,
      'requirements': result.requirements
          .map(
            (req) => {
              'requirement_id': req.requirementId,
              'requirement_name': req.requirementName,
              'subtotal_score': req.subtotalScore,
              'max_score': req.maxScore,
              'common_mistakes_detected': req.commonMistakesDetected,
              'matched_criteria': req.matchedCriteria,
              'missing_criteria': req.missingCriteria,
              'criteria': req.criteria
                  .map(
                    (crit) => {
                      'criterion_id': crit.criterionId,
                      'criterion_name': crit.criterionName,
                      'score_given': crit.scoreGiven,
                      'max_score': crit.maxScore,
                      'level_awarded': crit.levelAwarded,
                      'feedback': crit.feedback,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }
}
