class RubricLevel {
  final String scoreRange;
  final String description;

  RubricLevel({required this.scoreRange, required this.description});

  factory RubricLevel.fromJson(Map<String, dynamic> json) {
    return RubricLevel(
      scoreRange: json['score_range'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class RubricCriterion {
  final String id;
  final String name;
  final double maxPoints;
  final Map<String, RubricLevel> levels;

  RubricCriterion({
    required this.id,
    required this.name,
    required this.maxPoints,
    required this.levels,
  });

  factory RubricCriterion.fromJson(Map<String, dynamic> json) {
    final rawLevels = json['levels'] as Map<String, dynamic>? ?? const {};
    return RubricCriterion(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      maxPoints: (json['max_points'] as num?)?.toDouble() ?? 0.0,
      levels: rawLevels.map(
        (key, value) => MapEntry(
          key,
          RubricLevel.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
    );
  }
}

class RubricRequirement {
  final String id;
  final String name;
  final double maxPoints;
  final List<RubricCriterion> criteria;
  final List<String> commonMistakes;

  RubricRequirement({
    required this.id,
    required this.name,
    required this.maxPoints,
    required this.criteria,
    required this.commonMistakes,
  });

  factory RubricRequirement.fromJson(Map<String, dynamic> json) {
    final rawCriteria = json['criteria'] as List<dynamic>? ?? const [];
    final rawMistakes = json['common_mistakes'] as List<dynamic>? ?? const [];
    return RubricRequirement(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      maxPoints: (json['max_points'] as num?)?.toDouble() ?? 0.0,
      criteria: rawCriteria
          .map((e) => RubricCriterion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      commonMistakes: rawMistakes.map((e) => e.toString()).toList(),
    );
  }
}

class RubricExam {
  final String course;
  final String title;
  final double totalPoints;
  final String gradingScaleNote;
  final List<RubricRequirement> requirements;

  RubricExam({
    required this.course,
    required this.title,
    required this.totalPoints,
    required this.gradingScaleNote,
    required this.requirements,
  });

  factory RubricExam.fromJson(Map<String, dynamic> json) {
    final exam = json['exam'] as Map<String, dynamic>? ?? const {};
    final rawReqs = json['requirements'] as List<dynamic>? ?? const [];
    
    // Deduplicate requirements by ID
    final seenIds = <String>{};
    final uniqueRequirements = <RubricRequirement>[];
    
    for (final req in rawReqs) {
      final requirement = RubricRequirement.fromJson(Map<String, dynamic>.from(req as Map));
      if (!seenIds.contains(requirement.id)) {
        uniqueRequirements.add(requirement);
        seenIds.add(requirement.id);
      }
    }
    
    return RubricExam(
      course: exam['course'] as String? ?? '',
      title: exam['title'] as String? ?? '',
      totalPoints: (exam['total_points'] as num?)?.toDouble() ?? 100.0,
      gradingScaleNote: exam['grading_scale_note'] as String? ?? '',
      requirements: uniqueRequirements,
    );
  }
}
