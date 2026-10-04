import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/screens/anonymous_chat_screen.dart';
import 'package:tidewell_app/screens/cabin_dominoes_screen.dart';
import 'package:tidewell_app/screens/community_connect_screen.dart';
import 'package:tidewell_app/screens/guided_breathing_screen.dart';
import 'package:tidewell_app/screens/haven_screen.dart';
import 'package:tidewell_app/screens/journal_entry_screen.dart';
import 'package:tidewell_app/screens/knot_master_screen.dart';
import 'package:tidewell_app/screens/mindful_game_screen.dart';
import 'package:tidewell_app/screens/mood_check_in_screen.dart';
import 'package:tidewell_app/screens/off_watch_games_screen.dart';
import 'package:tidewell_app/screens/sextant_horizon_screen.dart';
import 'package:tidewell_app/screens/story_playback_screen.dart';
import 'package:tidewell_app/screens/weekly_insights_screen.dart';

void main() {
  // A phone-sized surface matching the Figma frames (402x874 logical).
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  testWidgets('mood check-in renders its sections', (tester) async {
    await pumpScreen(tester, const MoodCheckInScreen());
    expect(find.text('Log Emotional Swell'), findsOneWidget);
    expect(find.text('Gentle Swell'), findsOneWidget);
    expect(find.text('Secure in Logbook'), findsOneWidget);
  });

  testWidgets('guided breathing renders its cue', (tester) async {
    await pumpScreen(tester, const GuidedBreathingScreen());
    expect(find.text('Tidal Breath'), findsOneWidget);
    expect(find.text('Inhale with the Swell'), findsOneWidget);
  });

  testWidgets('journal entry renders its prompt', (tester) async {
    await pumpScreen(tester, const JournalEntryScreen());
    expect(find.text("Captain's Private Log"), findsOneWidget);
    expect(find.text('DAILY SEAPROMPT'), findsOneWidget);
  });

  testWidgets('crew renders the anchor pool tab by default', (tester) async {
    await pumpScreen(tester, const CommunityConnectScreen());
    // "Crew" appears twice: the screen header and the bottom-nav tab label.
    expect(find.text('Crew'), findsWidgets);
    expect(find.text('Anchor Pool'), findsOneWidget);
    expect(find.text('Cast to Fleet'), findsOneWidget);
  });

  testWidgets('crew fleet spirit tab reveals the leaderboard', (tester) async {
    await pumpScreen(tester, const CommunityConnectScreen());
    await tester.tap(find.text('Fleet Spirit'));
    await tester.pump();
    expect(find.text('Fleet Solidarity Log'), findsOneWidget);
    expect(find.text('Bosun Liam S.'), findsOneWidget);
  });

  testWidgets('haven hub renders its sections', (tester) async {
    await pumpScreen(tester, const HavenScreen());
    expect(find.text('Safe Haven'), findsOneWidget);
    expect(find.text('Tidal Breath'), findsOneWidget);
  });

  testWidgets('off-watch games hub renders featured + catalog', (tester) async {
    await pumpScreen(tester, const OffWatchGamesScreen());
    expect(find.text('Off-Watch Mind Games'), findsOneWidget);
    expect(find.text('Celestial Wayfinder'), findsOneWidget);
    expect(find.text('Calm Your Waves'), findsOneWidget);
  });

  testWidgets('story playback renders the featured tale', (tester) async {
    await pumpScreen(
      tester,
      const StoryPlaybackScreen(story: SeaStories.lighthouse),
    );
    expect(find.text('The Lighthouse at Cape Horn'), findsOneWidget);
    expect(find.text("Chapter 2: The Keeper's Lantern"), findsOneWidget);
  });

  testWidgets('weekly insights renders its cards', (tester) async {
    await pumpScreen(tester, const WeeklyInsightsScreen());
    expect(find.text('Sailing Wellness Log'), findsOneWidget);
    expect(find.text('Helmsman Advice'), findsOneWidget);
  });

  testWidgets('mindful game renders the board header', (tester) async {
    await pumpScreen(tester, const MindfulGameScreen());
    expect(find.text('Calm Your Waves'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
  });

  testWidgets('anonymous chat renders the thread', (tester) async {
    await pumpScreen(tester, const AnonymousChatScreen());
    expect(find.text('Safe Harbor Chat'), findsOneWidget);
    expect(find.text('Quiet Lighthouse'), findsWidgets);
  });

  testWidgets('knot master renders its tying arena', (tester) async {
    await pumpScreen(tester, const KnotMasterScreen());
    expect(find.text('Knot Master 3D'), findsOneWidget);
    expect(find.text('Tie the Bowline'), findsOneWidget);
    // Dispose the repeating pulse controller before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sextant horizon renders its vial', (tester) async {
    await pumpScreen(tester, const SextantHorizonScreen());
    expect(find.text('Sextant Horizon Balance'), findsOneWidget);
    expect(find.text('Hold the Horizon'), findsOneWidget);
    // Dispose the periodic calm-meter ticker + sensor subscription.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cabin dominoes renders its board', (tester) async {
    await pumpScreen(tester, const CabinDominoesScreen());
    expect(find.text('Cabin Dominoes'), findsOneWidget);
    expect(find.text('THE LINE'), findsOneWidget);
  });

  testWidgets('off-watch games hub wires the three new games', (tester) async {
    await pumpScreen(tester, const OffWatchGamesScreen());
    expect(find.text('Knot Master 3D'), findsOneWidget);
    expect(find.text('Sextant Horizon Balance'), findsOneWidget);
    expect(find.text('Cabin Dominoes'), findsOneWidget);
  });
}
