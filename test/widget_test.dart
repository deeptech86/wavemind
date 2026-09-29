import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/main.dart';
import 'package:tidewell_app/screens/home_dashboard_screen.dart';

void main() {
  testWidgets('Welcome screen renders and Embark navigates to dashboard', (
    WidgetTester tester,
  ) async {
    // Emulate a portrait phone (~402x874 logical, as in the Figma frames).
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TideWellApp());

    // Welcome screen content is present.
    expect(find.text('Tidewell'), findsOneWidget);
    expect(find.text('Your anchor in open waters'), findsOneWidget);
    expect(find.text('Embark'), findsOneWidget);

    // Tapping Embark navigates to the Home Dashboard.
    await tester.tap(find.text('Embark'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeDashboardScreen), findsOneWidget);
    expect(find.text('Marcus Thorne'), findsOneWidget);
    expect(find.text('MENTAL HELM CONTROLS'), findsOneWidget);
  });
}
