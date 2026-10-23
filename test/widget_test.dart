import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/screens/signup_screen.dart';
import 'package:tidewell_app/screens/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen renders and Embark opens Signup', (
    WidgetTester tester,
  ) async {
    // Emulate a portrait phone (~402x874 logical, as in the Figma frames).
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    // Welcome screen content is present.
    expect(find.text('Tidewell'), findsOneWidget);
    expect(find.text('Your anchor in open waters'), findsOneWidget);
    expect(find.text('Embark'), findsOneWidget);

    // Tapping Embark now opens the Signup screen (first-time framing), not the
    // dashboard — the app is gated behind auth.
    await tester.tap(find.text('Embark'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('Chart your course'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
