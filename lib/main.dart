import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/notifications/notification_provider.dart';
import 'core/notifications/notification_service.dart';
import 'screens/auth_gate.dart';
import 'screens/community_connect_screen.dart';
import 'screens/guided_breathing_screen.dart';
import 'screens/mood_check_in_screen.dart';
import 'theme/app_theme.dart';

/// Root navigator, used to open the right screen when a sailor taps a
/// notification — see [_onNotificationTap].
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notificationService.initialize(onNotificationTap: _onNotificationTap);
  runApp(const WavemindApp());
}

void _onNotificationTap(NotificationTarget target) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final screen = switch (target) {
    NotificationTarget.meditation => const GuidedBreathingScreen(),
    NotificationTarget.moodCheckIn => const MoodCheckInScreen(),
    NotificationTarget.competition => const CommunityConnectScreen(),
  };
  nav.push(MaterialPageRoute<void>(builder: (_) => screen));
}

class WavemindApp extends StatelessWidget {
  const WavemindApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wavemind uses light content on a dark, deep-sea backdrop.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Wavemind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // The auth gate validates any stored session token on launch and routes
      // to the Helm dashboard (valid) or the Welcome screen (missing/invalid).
      home: const AuthGate(),
    );
  }
}
