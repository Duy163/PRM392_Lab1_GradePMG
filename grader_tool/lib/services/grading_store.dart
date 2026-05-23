import 'dart:async';
import 'package:grader_tool/models/grading_result.dart';

class GradingStore {
  static final StreamController<List<GradingResult>> _controller =
      StreamController.broadcast();
  static final Map<String, GradingResult> _resultsByStudentFile = {};

  static Stream<List<GradingResult>> get stream => _controller.stream;
  static List<GradingResult> get latestResults {
    final list = _resultsByStudentFile.values.toList();
    list.sort((a, b) => _compareStudentFiles(a.studentFile, b.studentFile));
    return list;
  }

  static int _compareStudentFiles(String a, String b) {
    // Natural alphanumeric sorting (e.g. 1.txt, 2.txt, 10.txt)
    final reg = RegExp(r'(\d+)');
    final matchA = reg.firstMatch(a);
    final matchB = reg.firstMatch(b);
    if (matchA != null && matchB != null) {
      final intValA = int.parse(matchA.group(1)!);
      final intValB = int.parse(matchB.group(1)!);
      if (intValA != intValB) {
        return intValA.compareTo(intValB);
      }
    }
    return a.compareTo(b);
  }

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
