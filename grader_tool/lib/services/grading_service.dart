import 'package:grader_tool/models/grading_result.dart';
import 'package:grader_tool/services/file_reader_service.dart';
import 'package:grader_tool/services/ollama_service.dart';

class GradingService {
  /// Chạy quy trình chấm điểm toàn bộ
  static Future<List<GradingResult>> gradeAllStudents({
    required String solutionsFolderPath,
    required String criteriaDocPath,
    required Function(String) onProgress,
    required Function(String) onError,
  }) async {
    List<GradingResult> results = [];

    try {
      // 1. Đọc tiêu chí chấm điểm từ file Word
      onProgress('📖 Reading grading criteria...');
      final criteria = await FileReaderService.readDocxFile(criteriaDocPath);

      // 2. Lấy danh sách file bài làm của sinh viên
      onProgress('📂 Scanning student submissions...');
      final studentFiles = await FileReaderService.getStudentFiles(
        solutionsFolderPath,
      );

      if (studentFiles.isEmpty) {
        onError('❌ No .txt files found in the solutions folder');
        return [];
      }

      onProgress('🎯 Found ${studentFiles.length} student submissions');

      // 3. Chấm từng bài
      for (int i = 0; i < studentFiles.length; i++) {
        try {
          final file = studentFiles[i];
          final fileName = FileReaderService.getFileName(file.path);

          onProgress(
            '🔄 Grading (${i + 1}/${studentFiles.length}): $fileName...',
          );

          // Đọc nội dung bài làm
          final studentCode = await FileReaderService.readTxtFile(file.path);

          // Gọi Qwen AI để chấm
          final gradeResult = await OllamaService.gradeAssignment(
            criteria: criteria,
            studentCode: studentCode,
          );

          if (gradeResult['success']) {
            results.add(
              GradingResult(
                studentFile: fileName,
                score: (gradeResult['score'] as num).toDouble(),
                feedback: gradeResult['feedback'] as String,
                fullResponse: gradeResult['raw'] as String? ?? '',
              ),
            );
            onProgress(
              '✅ Graded $fileName - Score: ${gradeResult['score']}/10',
            );
          } else {
            onError('⚠️ Failed to grade $fileName: ${gradeResult['error']}');
            results.add(
              GradingResult(
                studentFile: fileName,
                score: 0.0,
                feedback: 'Error: ${gradeResult['error']}',
                fullResponse: '',
              ),
            );
          }

          // Thêm độ trễ giữa các request để tránh overload Ollama
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          onError('Error grading ${studentFiles[i].path}: $e');
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
