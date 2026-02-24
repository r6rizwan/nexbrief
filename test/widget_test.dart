import 'package:flutter_test/flutter_test.dart';

import 'package:nexbrief/main.dart';

void main() {
  testWidgets('renders meeting summarizer app', (WidgetTester tester) async {
    await tester.pumpWidget(const NexBriefApp());
    expect(find.text('NexBrief'), findsOneWidget);
  });
}
