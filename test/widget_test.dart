import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer_flutter/main.dart';

void main() {
  testWidgets('renders meeting summarizer app', (WidgetTester tester) async {
    await tester.pumpWidget(const MeetingSummarizerApp());
    expect(find.text('Meeting Summarizer + Action Extractor'), findsOneWidget);
  });
}
