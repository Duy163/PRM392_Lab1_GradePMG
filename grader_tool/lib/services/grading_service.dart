import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/services/file_reader_service.dart';
import 'package:grader_tool/services/ollama_service.dart';

class GradingService {
  /// Chạy quy trình chấm điểm toàn bộ
  static Future<List<GradingResult>> gradeAllStudents({
    required String criteriaDocPath,
    String? solutionsFolderPath,
    List<String>? selectedFilePaths,
    required Function(String) onProgress,
    required Function(String) onError,
  }) async {
    List<GradingResult> results = [];

    try {
      // 1. Đọc tiêu chí chấm điểm từ file Word
      onProgress('📖 Reading grading criteria...');
      final criteria = await FileReaderService.readDocxFile(criteriaDocPath);
      final expectedQuestionCount = FileReaderService.extractQuestionCount(
        criteria,
      );

      // 2. Lấy danh sách file bài làm của sinh viên
      onProgress('📂 Preparing student submissions...');

      List<String> targetPaths = [];
      if (selectedFilePaths != null && selectedFilePaths.isNotEmpty) {
        targetPaths = selectedFilePaths;
      } else if (solutionsFolderPath != null) {
        final studentFiles = await FileReaderService.getStudentFiles(
          solutionsFolderPath,
        );
        if (studentFiles.isEmpty) {
          onError('❌ No .txt files found in the solutions folder');
          return [];
        }
        targetPaths = studentFiles.map((f) => f.path).toList();
      } else {
        onError('❌ No solutions folder or selected files provided');
        return [];
      }

      onProgress('🎯 Found ${targetPaths.length} student submissions');

      // 3. Chấm từng bài
      for (int i = 0; i < targetPaths.length; i++) {
        try {
          final path = targetPaths[i];
          final fileName = FileReaderService.getFileName(path);

          onProgress(
            '🔄 Grading (${i + 1}/${targetPaths.length}): $fileName...',
          );

          // Đọc nội dung bài làm
          final studentCode = await FileReaderService.readTxtFile(path);

          // Gọi Qwen AI để chấm
          final gradeResult = await OllamaService.gradeAssignment(
            criteria: criteria,
            studentCode: studentCode,
            expectedQuestionCount: expectedQuestionCount > 0
                ? expectedQuestionCount
                : 4,
          );

          if (gradeResult['success']) {
            final gradingResultObj = GradingResult.fromJson(
              fileName,
              studentCode,
              gradeResult['json'] as Map<String, dynamic>,
            );
            results.add(gradingResultObj);
            onProgress(
              '✅ Graded $fileName - Score: ${gradingResultObj.score}/10',
            );
          } else {
            onError('⚠️ Failed to grade $fileName: ${gradeResult['error']}');
            results.add(
              GradingResult(
                studentFile: fileName,
                submissionContent: studentCode,
                questions: [],
                feedback: 'Error: ${gradeResult['error']}',
                fullResponse: '',
              ),
            );
          }

          // Thêm độ trễ giữa các request để tránh overload Ollama
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          onError('Error grading ${targetPaths[i]}: $e');
        }
      }

      onProgress(
        '✨ Grading complete! ${results.length} submissions processed.',
      );
      return results;
    } catch (e) {
      onError('Fatal error during grading process: $e');
      return [];
    }
  }
}
