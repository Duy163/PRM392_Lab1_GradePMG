import 'dart:async';
import 'package:grader_tool/models/grading_result.dart';

class GradingStore {
  static final StreamController<List<GradingResult>> _controller =
      StreamController.broadcast();
  static final Map<String, GradingResult> _resultsByStudentFile = {};

  static Stream<List<GradingResult>> get stream => _controller.stream;
  static List<GradingResult> get latestResults =>
      _resultsByStudentFile.values.toList();

  static void mergeResults(List<GradingResult> results) {
    for (final result in results) {
      _resultsByStudentFile[result.studentFile] = result;
    }
    _controller.add(latestResults);
  }

  static void replaceAll(List<GradingResult> results) {
    _resultsByStudentFile
      ..clear()
      ..addEntries(
        results.map((result) => MapEntry(result.studentFile, result)),
      );
    _controller.add(latestResults);
  }

  static void dispose() {
    _controller.close();
  }
}
