import 'package:flutter_test/flutter_test.dart';
import 'package:grader_tool/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const GraderApp());
  });
}
