import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:grader_tool/models/rubric.dart';
import 'package:grader_tool/services/app_state_store.dart';
import 'package:flutter/foundation.dart';

class OllamaService {
  static String? _cachedModelName;
  static DateTime? _cachedModelNameFetchedAt;
  static const Duration _modelCacheTtl = Duration(minutes: 5);

  static Future<Map<String, dynamic>> gradeAssignment({
    required RubricExam rubric,
    required String studentCode,
    String? rubricContext,
  }) async {
    // Skip Ollama LLM and use local keyword matcher if Fast Local mode is toggled
    if (AppStateStore.useFastGrader) {
      return _gradeWithKeywordMatcher(rubric, studentCode);
    }

    try {
      final modelName = await _getAvailableModel();
      if (modelName == null) {
        debugPrint('Ollama is offline. Falling back to keyword matcher.');
      } else {
        final prompt = _buildGradingPrompt(
          rubricContext ?? buildRubricContext(rubric),
          studentCode,
        );

        final response = await http
            .post(
              Uri.parse('http://localhost:11434/api/generate'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': modelName,
                'prompt': prompt,
                'stream': false,
                'format': 'json',
                'keep_alive': '30m',
                'options': {
                  'temperature': 0,
                  'num_predict': 400,
                  'top_p': 0.9,
                  'repeat_penalty': 1.05,
                  'num_ctx': 4096,
                },
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final responseText = resData['response'] as String;
          final jsonResult = jsonDecode(responseText) as Map<String, dynamic>;

          if (jsonResult.containsKey('total_score') &&
              (jsonResult['requirements'] is List ||
                  jsonResult['questions'] is List)) {
            // Align the JSON response with the official rubric to guarantee detailed criteria
            final alignedResult = _alignResultWithRubric(
              jsonResult: jsonResult,
              rubric: rubric,
            );

            return {
              'success': true,
              'json': alignedResult,
              'raw': responseText,
            };
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Error grading with Ollama: $e. Falling back to keyword matcher.',
      );
    }

    // Fallback: Local keyword matcher
    return _gradeWithKeywordMatcher(rubric, studentCode);
  }

  static Future<bool> testConnection() async {
    return (await _getAvailableModel()) != null;
  }

  static Future<String?> _getAvailableModel() async {
    final now = DateTime.now();
    if (_cachedModelName != null &&
        _cachedModelNameFetchedAt != null &&
        now.difference(_cachedModelNameFetchedAt!) < _modelCacheTtl) {
      return _cachedModelName;
    }

    try {
      final response = await http
          .get(Uri.parse('http://localhost:11434/api/tags'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List? models = data['models'] as List?;
        if (models != null && models.isNotEmpty) {
          _cachedModelName = models.first['name'] as String;
          _cachedModelNameFetchedAt = now;
          return _cachedModelName;
        }
      }
    } catch (_) {}

    _cachedModelName = null;
    _cachedModelNameFetchedAt = now;
    return null;
  }

  static Map<String, dynamic> _alignResultWithRubric({
    required Map<String, dynamic> jsonResult,
    required RubricExam rubric,
  }) {
    final rawReqList =
        jsonResult['requirements'] ?? jsonResult['questions'] ?? [];
    final jsonReqList = rawReqList is List
        ? rawReqList.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    // Build lookup map from the JSON by requirement_id or question_id (lowercased)
    final jsonReqMap = <String, Map<String, dynamic>>{};
    for (final jr in jsonReqList) {
      final id = (jr['requirement_id'] ?? jr['question_id'] ?? '')
          .toString()
          .toLowerCase();
      if (id.isNotEmpty) jsonReqMap[id] = jr;
    }

    final aligned = <Map<String, dynamic>>[];
    for (final req in rubric.requirements) {
      final key = req.id.toLowerCase();
      final found = jsonReqMap[key];
      if (found != null) {
        aligned.add(found);
      } else {
        aligned.add({
          'requirement_id': req.id,
          'requirement_name': req.name,
          'subtotal_score': 0,
          'max_score': req.maxPoints,
          'common_mistakes_detected': req.commonMistakes,
          'matched_criteria': <String>[],
          'missing_criteria': req.criteria.map((c) => c.id).toList(),
          'criteria': <Map<String, dynamic>>[],
        });
      }
    }

    return {
      'total_score': jsonResult['total_score'] ?? 0,
      'requirements': aligned,
      'questions': aligned,
    };
  }

  static String _buildGradingPrompt(String rubricContext, String studentCode) {
    return '''You are an expert academic grader. Grade the following student submission based on the provided rubric.

### Rubric:
$rubricContext

### Student Submission:
$studentCode

### Instructions:
Grade the student submission step-by-step for each criterion.
Provide your evaluation in JSON format only. The JSON response must have this exact structure:
{
  "total_score": <double>,
  "general_feedback": "<string>",
  "requirements": [
    {
      "requirement_id": "<string, e.g. YC1>",
      "requirement_name": "<string>",
      "subtotal_score": <double>,
      "max_score": <double>,
      "common_mistakes_detected": [<string>],
      "matched_criteria": [<string>],
      "missing_criteria": [<string>],
      "criteria": [
        {
          "criterion_id": "<string, e.g. 1.1>",
          "criterion_name": "<string>",
          "score_given": <double>,
          "max_score": <double>,
          "level_awarded": "<string, 'full' | 'partial' | 'fail'>",
          "feedback": "<string>"
        }
      ]
    }
  ]
}

Ensure the sum of requirement subtotal_scores equals total_score.
Do not output any introductory or concluding text, only the JSON block.
''';
  }

  static String buildRubricContext(RubricExam rubric) {
    final rubricBuf = StringBuffer();
    rubricBuf.writeln('Course: ${rubric.course}');
    rubricBuf.writeln('Title: ${rubric.title}');
    rubricBuf.writeln('Total Points: ${rubric.totalPoints}');
    rubricBuf.writeln('\nRequirements:');
    for (final req in rubric.requirements) {
      rubricBuf.writeln('- Requirement ID: ${req.id}');
      rubricBuf.writeln('  Name: ${req.name}');
      rubricBuf.writeln('  Max Points: ${req.maxPoints}');
      rubricBuf.writeln('  Criteria:');
      for (final c in req.criteria) {
        rubricBuf.writeln('    * Criterion ID: ${c.id}');
        rubricBuf.writeln('      Name: ${c.name}');
        rubricBuf.writeln('      Max Points: ${c.maxPoints}');
        rubricBuf.writeln(
          '      Full Match Description (100% score): "${c.levels['full']?.description ?? 'Đạt đầy đủ yêu cầu'}"',
        );
        rubricBuf.writeln(
          '      Partial Match Description (50-70% score): "${c.levels['partial']?.description ?? 'Đạt một phần yêu cầu'}"',
        );
        rubricBuf.writeln(
          '      Fail Match Description (<50% score): "${c.levels['fail']?.description ?? 'Chưa đạt yêu cầu'}"',
        );
      }
      if (req.commonMistakes.isNotEmpty) {
        rubricBuf.writeln(
          '  Common Mistakes to watch out for: ${req.commonMistakes.join("; ")}',
        );
      }
    }
    return rubricBuf.toString();
  }

  static Map<String, dynamic> _gradeWithKeywordMatcher(
    RubricExam rubric,
    String studentCode,
  ) {
    final normalized = _normalizeText(studentCode);
    final requirementResults = <Map<String, dynamic>>[];
    double total = 0;

    for (final requirement in rubric.requirements) {
      final requirementResult = _scoreRequirement(requirement, normalized);
      total += requirementResult['subtotal_score'] as double;

      requirementResults.add({
        'requirement_id': requirement.id,
        'requirement_name': requirement.name,
        'subtotal_score': requirementResult['subtotal_score'],
        'max_score': requirement.maxPoints,
        'common_mistakes_detected': requirement.commonMistakes,
        'matched_criteria': requirementResult['matched_criteria'],
        'missing_criteria': requirementResult['missing_criteria'],
        'feedback': _buildRequirementFeedback(requirementResult),
        'criteria': requirementResult['criteria'],
      });
    }

    return {
      'success': true,
      'json': {
        'total_score': double.parse(total.toStringAsFixed(2)),
        'scaled_score_out_of_10': double.parse(
          (total / 10.0).toStringAsFixed(2),
        ),
        'general_feedback': total <= 0
            ? 'Submission does not match rubric requirements.'
            : 'Graded using rubric JSON parsed from DOCX (Keyword Matcher Fallback).',
        'requirements': requirementResults,
        'questions': requirementResults,
      },
      'raw': 'rubric-json-parser',
    };
  }

  static Future<bool> testConnectionStub() async => true;

  static String _buildRequirementFeedback(
    Map<String, dynamic> requirementResult,
  ) {
    final matched =
        (requirementResult['matched_criteria'] as List?)?.cast<String>() ??
        const [];
    final missing =
        (requirementResult['missing_criteria'] as List?)?.cast<String>() ??
        const [];
    final parts = <String>[];
    if (matched.isNotEmpty) parts.add('Matched: ${matched.join(' | ')}');
    if (missing.isNotEmpty) parts.add('Missing: ${missing.join(' | ')}');
    if (parts.isEmpty) parts.add('No rubric evidence found.');
    return parts.join('. ');
  }

  static Map<String, dynamic> _scoreRequirement(
    RubricRequirement requirement,
    String normalizedSubmission,
  ) {
    debugPrint('\n=== Scoring Requirement: ${requirement.id} ===');
    debugPrint('Requirement name: ${requirement.name}');
    debugPrint('Criteria count in requirement: ${requirement.criteria.length}');

    final criterionResults = <Map<String, dynamic>>[];
    double subtotal = 0;
    final matched = <String>[];
    final missing = <String>[];

    for (final criterion in requirement.criteria) {
      debugPrint('  Processing criterion: ${criterion.id} - ${criterion.name}');
      final level = _evaluateCriterion(criterion, normalizedSubmission);
      final score = _scoreLevelScore(criterion.maxPoints, level);
      subtotal += score;
      debugPrint('    Level: $level, Score: $score/${criterion.maxPoints}');

      final feedback = criterion.levels[level]?.description ?? '';
      criterionResults.add({
        'criterion_id': criterion.id,
        'criterion_name': criterion.name,
        'score_given': score,
        'max_score': criterion.maxPoints,
        'level_awarded': level,
        'feedback': feedback,
      });

      if (score > 0) {
        matched.add('${criterion.id} ${criterion.name}');
      } else {
        missing.add('${criterion.id} ${criterion.name}');
      }
    }

    debugPrint('Total criteria results: ${criterionResults.length}');
    debugPrint('Subtotal score: $subtotal');

    return {
      'requirement_id': requirement.id,
      'requirement_name': requirement.name,
      'subtotal_score': double.parse(subtotal.toStringAsFixed(2)),
      'max_score': requirement.maxPoints,
      'common_mistakes_detected': _detectCommonMistakes(
        normalizedSubmission,
        requirement.commonMistakes,
      ),
      'matched_criteria': matched,
      'missing_criteria': missing,
      'criteria': criterionResults,
    };
  }

  static String _evaluateCriterion(
    RubricCriterion criterion,
    String normalizedSubmission,
  ) {
    final full = criterion.levels['full']?.description ?? '';
    final partial = criterion.levels['partial']?.description ?? '';

    if (_matchesDescription(normalizedSubmission, full, strong: true)) {
      return 'full';
    }
    if (_matchesDescription(normalizedSubmission, partial, strong: false)) {
      return 'partial';
    }
    return 'fail';
  }

  static bool _matchesDescription(
    String text,
    String description, {
    required bool strong,
  }) {
    final keywords = _keywordsFromText(description);
    if (keywords.isEmpty) return false;

    // Tính tỷ lệ từ khóa khớp để đánh giá nội dung tương tự
    final hits = keywords.where(text.contains).length;
    final matchRatio = keywords.isNotEmpty ? hits / keywords.length : 0.0;

    // Thử so sánh không dấu nếu so sánh có dấu không đủ
    var noDiacriticsHits = 0;
    if (matchRatio < 0.4) {
      final textNoDiacritics = _removeDiacritics(text);
      final keywordsNoDiacritics = keywords.map(_removeDiacritics).toList();
      noDiacriticsHits = keywordsNoDiacritics
          .where(textNoDiacritics.contains)
          .length;
      final noDiacriticsRatio = keywordsNoDiacritics.isNotEmpty
          ? noDiacriticsHits / keywordsNoDiacritics.length
          : 0.0;

      if (strong) {
        // Yêu cầu khớp ít nhất 35% từ khóa hoặc có chứa cụm từ chính
        return noDiacriticsRatio >= 0.35 ||
            _containsSimilarPhrase(
              textNoDiacritics,
              _removeDiacritics(description),
            );
      }
      // Partial chỉ cần 20% từ khóa khớp
      return noDiacriticsRatio >= 0.20;
    }

    if (strong) {
      // Yêu cầu khớp ít nhất 40% từ khóa hoặc có chứa cụm từ chính
      return matchRatio >= 0.4 || _containsSimilarPhrase(text, description);
    }
    // Partial chỉ cần 25% từ khóa khớp
    return matchRatio >= 0.25;
  }

  // Kiểm tra xem có chứa cụm từ tương tự không (so sánh nội dung)
  static bool _containsSimilarPhrase(String text, String description) {
    final descWords = _keywordsFromText(description);
    if (descWords.length < 3) return false;

    // Tìm chuỗi 3 từ liên tiếp trong description
    for (var i = 0; i <= descWords.length - 3; i++) {
      final phrase = descWords.sublist(i, i + 3);
      var foundCount = 0;
      for (final word in phrase) {
        if (text.contains(word)) foundCount++;
      }
      // Nếu tìm thấy 2/3 từ trong cụm, coi như khớp
      if (foundCount >= 2) return true;
    }
    return false;
  }

  static double _scoreLevelScore(double maxPoints, String level) {
    if (level == 'full') return maxPoints;
    if (level == 'partial') {
      return double.parse((maxPoints * 0.6).toStringAsFixed(2));
    }
    return 0.0;
  }

  static List<String> _detectCommonMistakes(
    String normalizedSubmission,
    List<String> mistakes,
  ) {
    final detected = <String>[];
    for (final mistake in mistakes) {
      final keys = _keywordsFromText(mistake);
      if (keys.isEmpty) continue;
      final hit = keys.where(normalizedSubmission.contains).length;
      if (hit >= 1) detected.add(mistake);
    }
    return detected;
  }

  static List<String> _keywordsFromText(String input) {
    final normalized = _normalizeText(input);
    // Lọc bỏ stop words phổ biến để tập trung vào từ khóa quan trọng
    final stopWords = {
      'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'should',
      'can', 'could', 'may', 'might', 'must', 'shall',
      'va', 'cua', 'cho', 'voi', 'tren', 'duoi', 'trong', 'ngoai', // Vietnamese
      'la', 'co', 'khong', 'da', 'se', 'dang', 'duoc', 'den', 'tu',
    };

    return normalized
        .split(' ')
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .toList();
  }

  static String _normalizeText(String input) {
    // Giữ nguyên tiếng Việt có dấu, chỉ loại bỏ ký tự đặc biệt
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Hàm bổ sung: loại bỏ dấu tiếng Việt để so sánh linh hoạt hơn
  static String _removeDiacritics(String input) {
    const vietnamese =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const normalized =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    var result = input.toLowerCase();
    for (var i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], normalized[i]);
    }
    return result;
  }
}
