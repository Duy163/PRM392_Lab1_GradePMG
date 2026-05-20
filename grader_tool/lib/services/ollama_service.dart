import 'package:http/http.dart' as http;
import 'dart:convert';

class OllamaService {
  static const String baseUrl = 'http://localhost:11434/api/generate';
  static const String modelName =
      'qwen2.5:7b'; // Hoặc qwen2.5:14b nếu máy đủ RAM

  /// Gọi Ollama API để chấm bài
  static Future<Map<String, dynamic>> gradeAssignment({
    required String criteria,
    required String studentCode,
  }) async {
    final prompt =
        '''You are an experienced programming teacher. 
Grading Criteria:
$criteria

Student's Submission:
$studentCode

Please grade this submission. Respond with ONLY a JSON object (no markdown, no extra text) in this format:
{"score": <number between 0-10>, "feedback": "<detailed explanation>"}''';

    try {
      print('🚀 Sending request to Ollama...');
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': modelName,
              'prompt': prompt,
              'stream': false,
              'temperature': 0.7,
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

      print('✅ Ollama response received');
      print(
        'Response preview: ${responseText.substring(0, min(200, responseText.length))}...',
      );

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

      return {
        'success': true,
        'score': result['score'] ?? 0.0,
        'feedback': result['feedback'] ?? 'No feedback provided',
        'raw': responseText,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'score': 0.0,
        'feedback': 'Error occurred while grading',
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
        print('✅ Connected to Ollama successfully');
        final data = jsonDecode(response.body);
        final models = data['models'] as List?;
        print('Available models: ${models?.map((m) => m['name']).toList()}');
        return true;
      }
      print('❌ Ollama connection failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Ollama connection error: $e');
      return false;
    }
  }
}

int min(int a, int b) => a < b ? a : b;
