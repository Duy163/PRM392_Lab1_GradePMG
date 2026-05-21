import 'package:http/http.dart' as http;
import 'dart:convert';

class OllamaService {
  static const String baseUrl = 'http://localhost:11434/api/generate';
  static const String modelName =
      'qwen2.5:1.5b'; // Đổi sang bản nhẹ hơn vì máy thiếu RAM

  /// Gọi Ollama API để chấm bài
  static Future<Map<String, dynamic>> gradeAssignment({
    required String criteria,
    required String studentCode,
    required int expectedQuestionCount,
  }) async {
    final prompt =
        '''You are an experienced programming teacher.
Grading Criteria:
$criteria

Student's Submission:
$studentCode

Please grade this submission question by question based on the criteria.
CRITICAL INSTRUCTIONS:
1. You MUST grade EVERY question listed in the Grading Criteria. The criteria contains exactly $expectedQuestionCount questions, so your "questions" array MUST have exactly $expectedQuestionCount items.
2. If the student completely skipped a question, you must still include it in the array with a score of 0 and state that it was missing.

Respond with ONLY a JSON object (no markdown, no extra text) in this exact format:
{
  "total_score": <number between 0-10>,
  "general_feedback": "<overall comments>",
  "questions": [
    {
      "question_number": <number>,
      "score": <number>,
      "mistake": "<describe what they did wrong, or 'None'>",
      "feedback": "<detailed explanation for this question>"
    }
  ]
}''';

    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': modelName,
              'prompt': prompt,
              'stream': false,
              'temperature': 0.0,
            }),
          )
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () =>
                throw Exception('Ollama request timeout - is Ollama running?'),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'Ollama error: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final responseText = data['response'] as String? ?? '';

      // Extract JSON from response (Qwen sometimes adds extra text)
      final jsonMatch = RegExp(
        r'\{.*\}',
        dotAll: true,
      ).firstMatch(responseText);
      if (jsonMatch == null) {
        throw Exception('Could not extract JSON from Ollama response');
      }

      final jsonStr = jsonMatch.group(0)!;
      final result = jsonDecode(jsonStr) as Map<String, dynamic>;

      final normalized = _normalizeQuestions(result, expectedQuestionCount);

      return {'success': true, 'json': normalized, 'raw': responseText};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'json': <String, dynamic>{},
      };
    }
  }

  /// Test kết nối đến Ollama
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:11434/api/tags'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic> _normalizeQuestions(
    Map<String, dynamic> result,
    int expectedQuestionCount,
  ) {
    final questions = <Map<String, dynamic>>[];
    final rawQuestions = result['questions'];

    if (rawQuestions is List) {
      for (final item in rawQuestions) {
        if (item is Map<String, dynamic>) {
          questions.add(Map<String, dynamic>.from(item));
        } else if (item is Map) {
          questions.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final byNumber = <int, Map<String, dynamic>>{};
    for (final question in questions) {
      final number = int.tryParse(
        question['question_number']?.toString() ?? '',
      );
      if (number != null && number > 0) {
        byNumber[number] = question;
      }
    }

    final normalizedQuestions = <Map<String, dynamic>>[];
    for (var i = 1; i <= expectedQuestionCount; i++) {
      normalizedQuestions.add(
        byNumber[i] ??
            <String, dynamic>{
              'question_number': i,
              'score': 0,
              'mistake': 'Missing from model response',
              'feedback':
                  'This question was not returned by the model and was padded by the app.',
            },
      );
    }

    result['questions'] = normalizedQuestions;
    return result;
  }
}
