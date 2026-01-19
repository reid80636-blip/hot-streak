import 'package:flutter_test/flutter_test.dart';

import 'package:hotstreak/app.dart';

void main() {
  testWidgets('HotStreak app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HotStreakApp());

    // Verify the app loads (splash screen should be shown)
    await tester.pump();

    // Basic smoke test - app should launch without errors
    expect(find.byType(HotStreakApp), findsOneWidget);
  });
}
