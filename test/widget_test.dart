import 'package:flutter_test/flutter_test.dart';

import 'package:fall_down_detection_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FallDetectorApp());

    // Verify that the app title is present
    expect(find.text('Fall Detector'), findsOneWidget);

    // Verify that the welcome message is displayed
    expect(find.text('All Clear — No Fall Detected'), findsOneWidget);

    // Verify test buttons are present
    expect(find.text('Random\nData'), findsOneWidget);
    expect(find.text('Fall\nDetected'), findsOneWidget);
    expect(find.text('No Fall\nDetected'), findsOneWidget);
  });
}
