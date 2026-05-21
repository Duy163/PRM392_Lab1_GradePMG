class QuestionScore {
  final int questionNumber;
  double score;
  final String mistake;
  final String feedback;

  QuestionScore({
    required this.questionNumber,
    required this.score,
    required this.mistake,
    required this.feedback,
  });

  factory QuestionScore.fromJson(Map<String, dynamic> json) {
    return QuestionScore(
      questionNumber: json['question_number'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      mistake: json['mistake'] as String? ?? 'None',
      feedback: json['feedback'] as String? ?? 'No feedback',
    );
  }

  Map<String, dynamic> toJson() => {
        'question_number': questionNumber,
        'score': score,
        'mistake': mistake,
        'feedback': feedback,
      };

}

class GradingResult {
  final String studentFile;
  final String submissionContent;
  final List<QuestionScore> questions;
  final String feedback;
  final String fullResponse;

  double get score => questions.fold(0.0, (sum, q) => sum + q.score);

  GradingResult({
    required this.studentFile,
    required this.submissionContent,
    required this.questions,
    required this.feedback,
    required this.fullResponse,
  });

  factory GradingResult.fromJson(
    String studentFile,
    String submissionContent,
    Map<String, dynamic> json,
  ) {
    var questionsJson = json['questions'] as List?;
    List<QuestionScore> qs = [];
    if (questionsJson != null) {
      for (var q in questionsJson) {
        if (q is Map<String, dynamic>) {
          qs.add(QuestionScore.fromJson(q));
        } else if (q is Map) {
          qs.add(QuestionScore.fromJson(Map<String, dynamic>.from(q)));
        }
      }
    }

    return GradingResult(
      studentFile: studentFile,
      submissionContent: submissionContent,
      questions: qs,
      feedback: json['general_feedback'] as String? ??
          json['feedback'] as String? ??
          'No overall feedback',
      fullResponse: json.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'student': studentFile,
        'submission_content': submissionContent,
        'score': score,
        'general_feedback': feedback,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}
