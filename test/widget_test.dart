// This is a basic Flutter widget test.
//
import 'package:flutter_test/flutter_test.dart';

import 'package:ss_mart/app.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SSMartApp());

    // Verify that the app loads - check for login page
    expect(find.text('Login'), findsOneWidget);
  });
}