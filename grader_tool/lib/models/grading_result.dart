class GradingResult {
  final String studentFile;
  final double score;
  final String feedback;
  final String fullResponse;

  GradingResult({
    required this.studentFile,
    required this.score,
    required this.feedback,
    required this.fullResponse,
  });

  factory GradingResult.fromJson(
    String studentFile,
    Map<String, dynamic> json,
  ) {
    return GradingResult(
      studentFile: studentFile,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback'] as String? ?? 'No feedback',
      fullResponse: json.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'student': studentFile,
    'score': score,
    'feedback': feedback,
  };
}
