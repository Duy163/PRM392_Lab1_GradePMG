class CriterionScore {
  final String criterionId;
  final String criterionName;
  final double scoreGiven;
  final double maxScore;
  final String levelAwarded;
  final String feedback;

  CriterionScore({
    required this.criterionId,
    required this.criterionName,
    required this.scoreGiven,
    required this.maxScore,
    required this.levelAwarded,
    required this.feedback,
  });

  factory CriterionScore.fromJson(Map<String, dynamic> json) {
    return CriterionScore(
      criterionId: json['criterion_id'] as String? ?? '',
      criterionName: json['criterion_name'] as String? ?? '',
      scoreGiven: (json['score_given'] as num?)?.toDouble() ?? 0.0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0.0,
      levelAwarded: json['level_awarded'] as String? ?? 'fail',
      feedback: json['feedback'] as String? ?? '',
    );
  }
}

class RequirementScore {
  final String requirementId;
  final String requirementName;
  final double subtotalScore;
  final double maxScore;
  final List<String> commonMistakesDetected;
  final List<String> matchedCriteria;
  final List<String> missingCriteria;
  final List<CriterionScore> criteria;

  RequirementScore({
    required this.requirementId,
    required this.requirementName,
    required this.subtotalScore,
    required this.maxScore,
    required this.commonMistakesDetected,
    required this.matchedCriteria,
    required this.missingCriteria,
    required this.criteria,
  });

  factory RequirementScore.fromJson(Map<String, dynamic> json) {
    final rawCriteria = json['criteria'] as List? ?? const [];
    final rawMatched = json['matched_criteria'] ?? json['matched_requirements'];
    final rawMissing = json['missing_criteria'] ?? json['missing_requirements'];
    return RequirementScore(
      requirementId:
          json['requirement_id'] as String? ??
          json['question_id'] as String? ??
          '',
      requirementName:
          json['requirement_name'] as String? ??
          json['question_name'] as String? ??
          '',
      subtotalScore:
          (json['subtotal_score'] as num?)?.toDouble() ??
          (json['score'] as num?)?.toDouble() ??
          0.0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0.0,
      commonMistakesDetected:
          (json['common_mistakes_detected'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      matchedCriteria:
          (rawMatched as List?)?.map((e) => e.toString()).toList() ?? const [],
      missingCriteria:
          (rawMissing as List?)?.map((e) => e.toString()).toList() ?? const [],
      criteria: rawCriteria
          .map(
            (e) => CriterionScore.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

class GradingResult {
  final String studentFile;
  final String submissionContent;
  final List<RequirementScore> requirements;
  double? totalScore;
  final String feedback;
  final String fullResponse;

  double get score =>
      totalScore ?? requirements.fold(0.0, (sum, r) => sum + r.subtotalScore);

  GradingResult({
    required this.studentFile,
    required this.submissionContent,
    required this.requirements,
    this.totalScore,
    required this.feedback,
    required this.fullResponse,
  });

  factory GradingResult.fromJson(
    String studentFile,
    String submissionContent,
    Map<String, dynamic> json,
  ) {
    final rawRequirements =
        (json['requirements'] as List?) ??
        (json['questions'] as List?) ??
        const [];
    final reqs = rawRequirements
        .map(
          (e) => RequirementScore.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    final rawTotal = (json['total_score'] as num?)?.toDouble() ?? 0.0;
    return GradingResult(
      studentFile: studentFile,
      submissionContent: submissionContent,
      requirements: reqs,
      totalScore: rawTotal > 0 ? rawTotal : null,
      feedback:
          json['general_feedback'] as String? ??
          json['overall_feedback'] as String? ??
          'No overall feedback',
      fullResponse: json.toString(),
    );
  }
}
