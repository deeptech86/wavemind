import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wavemind_app/core/notifications/notification_service.dart';
import 'package:wavemind_app/data/auth_api.dart';
import 'package:wavemind_app/data/auth_token_storage.dart';
import 'package:wavemind_app/data/crew_message_service.dart';
import 'package:wavemind_app/data/crew_mood_service.dart';
import 'package:wavemind_app/data/games/calm_your_waves.dart';
import 'package:wavemind_app/data/leaderboard_service.dart';
import 'package:wavemind_app/data/models/account.dart';
import 'package:wavemind_app/data/profile_photo_service.dart';
import 'package:wavemind_app/screens/auth_gate.dart';
import 'package:wavemind_app/screens/home_dashboard_screen.dart';
import 'package:wavemind_app/screens/login_screen.dart';
import 'package:wavemind_app/screens/profile_screen.dart';
import 'package:wavemind_app/screens/signup_screen.dart';
import 'package:wavemind_app/screens/welcome_screen.dart';
import 'package:wavemind_app/screens/cabin_dominoes_screen.dart';
import 'package:wavemind_app/screens/community_connect_screen.dart';
import 'package:wavemind_app/screens/fog_signal_echo_screen.dart';
import 'package:wavemind_app/screens/game_catalog.dart';
import 'package:wavemind_app/screens/guided_breathing_screen.dart';
import 'package:wavemind_app/screens/haven_screen.dart';
import 'package:wavemind_app/screens/journal_entry_screen.dart';
import 'package:wavemind_app/screens/knot_master_screen.dart';
import 'package:wavemind_app/screens/mindful_game_screen.dart';
import 'package:wavemind_app/screens/mood_check_in_screen.dart';
import 'package:wavemind_app/screens/off_watch_games_screen.dart';
import 'package:wavemind_app/screens/matchstick_puzzle_screen.dart';
import 'package:wavemind_app/screens/sextant_horizon_screen.dart';
import 'package:wavemind_app/screens/stone_cairn_screen.dart';
import 'package:wavemind_app/screens/story_playback_screen.dart';
import 'package:wavemind_app/screens/weekly_insights_screen.dart';

void main() {
  // A phone-sized surface matching the Figma frames (402x874 logical).
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  // The real AuthTokenStorage hits a platform channel with no mock handler
  // registered in widget tests and never resolves — every Helm/Crew screen
  // construction below must inject these instead so every backend sync
  // degrades to "no session" immediately rather than hanging (fatal under
  // pumpAndSettle, which never returns while a future never resolves).
  LeaderboardService noLeaderboardSync() =>
      LeaderboardService(tokenStorage: _FakeTokenStorage(null));
  CrewMoodService noCrewMoodSync() =>
      CrewMoodService(tokenStorage: _FakeTokenStorage(null));
  CrewMessageService noCrewMessageSync() =>
      CrewMessageService(tokenStorage: _FakeTokenStorage(null));
  // Same reasoning: path_provider has no mock registered either.
  ProfilePhotoService noPhoto() => _FakePhotoService();
  // The real LocalNotificationService hits a platform channel too.
  NotificationService noNotifications() => _FakeNotificationService();

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

  testWidgets(
    'helm shows the voyage to victory banner (not the old story promo)',
    (tester) async {
      await pumpScreen(
        tester,
        HomeDashboardScreen(
          leaderboardService: noLeaderboardSync(),
          photoService: noPhoto(),
          tokenStorage: _FakeTokenStorage(null),
          notificationService: noNotifications(),
        ),
      );
      await tester
          .pumpAndSettle(); // let the backend rank sync settle (fails gracefully)
      expect(find.text('VOYAGE TO VICTORY'), findsOneWidget);
      expect(
        find.text('0 Fleet Knots'),
        findsOneWidget,
      ); // empty ledger default
      // No backend reachable in widget tests: the rank degrades gracefully
      // (no fake rank) rather than showing a mock-derived number.
      expect(find.textContaining('Rank #'), findsNothing);
      // The removed Off-Watch Story banner must be gone from Helm.
      expect(find.text('OFF-WATCH STORY'), findsNothing);
      expect(find.text('The Lighthouse at Cape Horn'), findsNothing);
    },
  );

  testWidgets(
    'helm voyage details starts on the ask-form with no saved status',
    (tester) async {
      await pumpScreen(
        tester,
        HomeDashboardScreen(
          leaderboardService: noLeaderboardSync(),
          photoService: noPhoto(),
          tokenStorage: _FakeTokenStorage(null),
          notificationService: noNotifications(),
        ),
      );
      await tester.pump();
      expect(find.text('Voyage Details'), findsOneWidget);
      expect(find.text('Docked'), findsOneWidget);
      expect(find.text('Voyage'), findsOneWidget);
      // Voyage-only fields stay hidden until that radio is selected.
      expect(find.text('FROM'), findsNothing);
    },
  );

  testWidgets('helm voyage form reveals From/To/Days when Voyage is picked', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      HomeDashboardScreen(
        leaderboardService: noLeaderboardSync(),
        photoService: noPhoto(),
        tokenStorage: _FakeTokenStorage(null),
        notificationService: noNotifications(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Voyage'));
    await tester.pump();
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(find.text('DAYS REMAINING'), findsOneWidget);
  });

  testWidgets(
    'helm voyage saving Docked collapses to a summary + Edit button',
    (tester) async {
      await pumpScreen(
        tester,
        HomeDashboardScreen(
          leaderboardService: noLeaderboardSync(),
          photoService: noPhoto(),
          tokenStorage: _FakeTokenStorage(null),
          notificationService: noNotifications(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Save')); // Docked needs no extra fields.
      await tester.pump();
      expect(find.text('Voyage Details'), findsNothing);
      expect(find.text('Docked'), findsOneWidget);
      expect(find.text('No active voyage'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );

  testWidgets('helm voyage Edit reopens the ask-form', (tester) async {
    await pumpScreen(
      tester,
      HomeDashboardScreen(
        leaderboardService: noLeaderboardSync(),
        photoService: noPhoto(),
        tokenStorage: _FakeTokenStorage(null),
        notificationService: noNotifications(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Edit'));
    await tester.pump();
    expect(find.text('Voyage Details'), findsOneWidget);
  });

  testWidgets(
    'helm voyage From/To autocomplete port suggestions by city name',
    (tester) async {
      await pumpScreen(
        tester,
        HomeDashboardScreen(
          leaderboardService: noLeaderboardSync(),
          photoService: noPhoto(),
          tokenStorage: _FakeTokenStorage(null),
          notificationService: noNotifications(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Voyage'));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Yoko');
      await tester.pumpAndSettle();
      expect(find.text('Yokohama, Japan'), findsOneWidget);
      await tester.tap(find.text('Yokohama, Japan'));
      await tester.pumpAndSettle();

      await tester.enterText(fields.at(1), 'Valpara');
      await tester.pumpAndSettle();
      expect(find.text('Valparaiso, Chile'), findsOneWidget);
      await tester.tap(find.text('Valparaiso, Chile'));
      await tester.pumpAndSettle();

      await tester.enterText(fields.at(2), '21');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(
        find.text('Voyage: Yokohama, Japan to Valparaiso, Chile'),
        findsOneWidget,
      );
    },
  );

  testWidgets('crew renders the fleet spirit tab by default', (tester) async {
    await pumpScreen(
      tester,
      CommunityConnectScreen(
        leaderboardService: noLeaderboardSync(),
        crewMoodService: noCrewMoodSync(),
        crewMessageService: noCrewMessageSync(),
      ),
    );
    await tester
        .pumpAndSettle(); // let the Voyage Milestone + leaderboard sync settle
    // "Crew" appears twice: the screen header and the bottom-nav tab label.
    expect(find.text('Crew'), findsWidgets);
    expect(find.text('Fleet Spirit'), findsOneWidget);
    expect(find.text('Leadership Board'), findsOneWidget);
    // Anchor Pool content is not shown until that tab is selected.
    expect(find.text('Cast to Fleet'), findsNothing);
    // No voyage saved (nothing to read with no native DB in widget tests):
    // the milestone card falls back to its docked state, not fictional stats.
    expect(find.text('Docked'), findsOneWidget);
    expect(
      find.text('Set sail from the Helm to track your voyage here.'),
      findsOneWidget,
    );
    // No backend reachable in widget tests: the real leaderboard degrades
    // gracefully (no fake competitor rows) rather than showing mock data.
    expect(
      find.textContaining('Leadership Board is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('crew tabs switch between fleet spirit and anchor pool', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      CommunityConnectScreen(
        leaderboardService: noLeaderboardSync(),
        crewMoodService: noCrewMoodSync(),
        crewMessageService: noCrewMessageSync(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leadership Board'), findsOneWidget);
    await tester.tap(find.text('Anchor Pool'));
    await tester.pump();
    expect(find.text('Cast to Fleet'), findsOneWidget);
    expect(find.text('Leadership Board'), findsNothing);
    // No backend reachable in widget tests: both real Anchor Pool features
    // degrade gracefully rather than showing the old static placeholders.
    expect(find.text('Anonymized Crew Swell'), findsOneWidget);
    expect(
      find.text(
        'Crew Swell is unavailable right now — check the backend '
        'connection and reopen Crew.',
      ),
      findsOneWidget,
    );
    expect(find.text('82%'), findsNothing);
    expect(
      find.text(
        'No gratitude notes yet — cast a float bottle above to be the '
        'first.',
      ),
      findsOneWidget,
    );
    expect(find.text('Anonymous Deckhand'), findsNothing);
  });

  testWidgets('crew opens directly on Fleet Spirit via initialTab', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      CommunityConnectScreen(
        initialTab: CrewTab.fleetSpirit,
        leaderboardService: noLeaderboardSync(),
        crewMoodService: noCrewMoodSync(),
        crewMessageService: noCrewMessageSync(),
      ),
    );
    await tester.pumpAndSettle();
    // Lands on the leaderboard immediately — no tab tap required.
    expect(find.text('Leadership Board'), findsOneWidget);
    expect(find.text('YOUR CONTRIBUTION'), findsOneWidget);
    // No backend reachable in widget tests: the rank badge degrades
    // gracefully rather than showing a fake number.
    expect(find.text('Rank —'), findsOneWidget);
  });

  testWidgets('haven hub renders its sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HavenScreen()));
    await tester.pump();

    expect(find.text('Safe Haven'), findsOneWidget);
    expect(find.text('Tidal Breath'), findsOneWidget);
    // Off-Watch Mind Games moved here, between Sleep Lore and Ambient Sounds.
    expect(find.text('OFF-WATCH MIND GAMES'), findsOneWidget);
    // _SectionHeader upper-cases its title.
    expect(find.text('AMBIENT CABIN SOUNDSCAPES'), findsOneWidget);

    // Capped to this week's 2 games (random-but-stable per week; no sync in
    // a widget test, so this is the client-side weeklyGames() fallback —
    // same thing the screen itself falls back to).
    final thisWeek = weeklyGames(DateTime.now());
    expect(thisWeek, hasLength(2));
    for (final game in thisWeek) {
      expect(find.text(game.title), findsOneWidget);
    }
    final notThisWeek = [
      for (final g in gameCatalog)
        if (!thisWeek.any((w) => w.key == g.key)) g,
    ];
    for (final game in notThisWeek) {
      expect(find.text(game.title), findsNothing);
    }
  });

  testWidgets('off-watch games hub renders the catalog', (tester) async {
    await pumpScreen(tester, const OffWatchGamesScreen());
    expect(find.text('Off-Watch Mind Games'), findsOneWidget);
    // The "Celestial Wayfinder" featured-ritual placeholder was removed —
    // it was never a real game, just a "coming soon" mockup.
    expect(find.text('Celestial Wayfinder'), findsNothing);
    expect(find.text('Maritime Mind Catalog'), findsOneWidget);
    expect(find.textContaining('of ${gameCatalog.length} this week'), findsOneWidget);
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
    await pumpScreen(tester, MindfulGameScreen(random: Random(1)));
    expect(find.text('Calm Your Waves'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget); // level 1 of 10
    // Drain the initial 3s preview-flash timer so it doesn't fire after the
    // test ends.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('mindful game: tapping a matching pair clears it', (tester) async {
    // Same seed the screen below uses for its level-0 board, so the matching
    // partner index is known ahead of time.
    final reference = CalmYourWaves.level(0, random: Random(1));
    final design = reference.designs[0];
    final partner = reference.designs.indexOf(design, 1);

    await pumpScreen(tester, MindfulGameScreen(random: Random(1)));
    expect(find.text('0 / 2'), findsOneWidget); // no pairs matched yet
    // Let the 3s preview flash finish before tapping.
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('calm_tile_0')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('calm_tile_$partner')));
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget); // one pair matched
  });

  testWidgets('knot master renders its tying arena', (tester) async {
    await pumpScreen(tester, const KnotMasterScreen());
    expect(find.text('Knot Master 3D'), findsOneWidget);
    expect(find.text('Close the Loop'), findsOneWidget);
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

  testWidgets('fog signal echo renders its signal pads', (tester) async {
    await pumpScreen(tester, const FogSignalEchoScreen());
    expect(find.text('Fog Signal Echo'), findsOneWidget);
    expect(find.text('Echo the Signal'), findsOneWidget);
    expect(find.text('Bow'), findsOneWidget);
    expect(find.text('Starboard'), findsOneWidget);
    expect(find.text('Stern'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);
    expect(find.text('Start Listening'), findsOneWidget);
  });

  testWidgets('fog signal echo starting a round shows the round counter', (
    tester,
  ) async {
    await pumpScreen(tester, const FogSignalEchoScreen());
    await tester.tap(find.text('Start Listening'));
    await tester.pump();
    expect(find.text('1 / 8'), findsOneWidget);
    expect(find.text('Listen…'), findsOneWidget);
    // Drain the tone-playback + inter-note delay timers (fake-clock time,
    // not real I/O) so none are still pending when the test ends.
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('cabin dominoes renders its board', (tester) async {
    await pumpScreen(tester, const CabinDominoesScreen());
    expect(find.text('Cabin Dominoes'), findsOneWidget);
    expect(find.text('THE LINE'), findsOneWidget);
  });

  testWidgets('stone cairn renders its arena and tray', (tester) async {
    // Wide enough that the 7-stone tray row (a horizontal ListView) is fully
    // built — it lazily builds only what's on/near screen.
    await tester.binding.setSurfaceSize(const Size(900, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: StoneCairnScreen(random: Random(1))),
    );
    await tester.pump();

    expect(find.text('Stone Cairn Balance'), findsOneWidget);
    expect(find.text('Build Your Cairn'), findsOneWidget);
    expect(find.text('0 / 7'), findsOneWidget); // nothing placed yet
    expect(find.text('New Stones'), findsOneWidget);
    expect(find.byType(Draggable<int>), findsNWidgets(7)); // the tray stones
  });

  testWidgets('matchstick puzzle renders a puzzle with instructions', (
    tester,
  ) async {
    await pumpScreen(tester, MatchstickPuzzleScreen(random: Random(1)));
    expect(find.text('Matchstick Puzzle'), findsOneWidget);
    expect(find.text('Shift One Stick'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('New Puzzle'), findsOneWidget);
  });

  testWidgets('matchstick puzzle: dragging the known stick solves it', (
    tester,
  ) async {
    // Seed 8 selects bank puzzle index 0 ("3+2=3"); its known solution drags
    // the result digit's topRight stick (token 4, segment 2) onto its
    // topLeft slot (token 4, segment 1), turning 3+2=3 into 3+2=5.
    await pumpScreen(tester, MatchstickPuzzleScreen(random: Random(8)));

    final source = find.byKey(const ValueKey('match_stick_4_2'));
    final destination = find.byKey(const ValueKey('match_slot_4_1'));
    expect(source, findsOneWidget);
    expect(destination, findsOneWidget);

    final delta = tester.getCenter(destination) - tester.getCenter(source);
    await tester.drag(source, delta);
    await tester.pump();

    expect(find.text('Solved!'), findsOneWidget);
  });

  testWidgets('off-watch games hub shows only this week\'s 2 games', (
    tester,
  ) async {
    await pumpScreen(tester, const OffWatchGamesScreen());

    // No sync in a widget test, so the screen falls back to the same
    // client-side weeklyGames() the test computes here.
    final thisWeek = weeklyGames(DateTime.now());
    expect(thisWeek, hasLength(2));
    for (final game in thisWeek) {
      expect(find.text(game.title), findsOneWidget);
    }
    final notThisWeek = [
      for (final g in gameCatalog)
        if (!thisWeek.any((w) => w.key == g.key)) g,
    ];
    for (final game in notThisWeek) {
      expect(find.text(game.title), findsNothing);
    }
  });

  testWidgets('login screen renders its fields + cross-link', (tester) async {
    await pumpScreen(tester, const LoginScreen());
    expect(find.text('Welcome back aboard'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('signup screen renders all fields incl. optional fleet', (
    tester,
  ) async {
    await pumpScreen(tester, const SignupScreen());
    expect(find.text('Chart your course'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('AGE'), findsOneWidget);
    expect(find.text('SEX'), findsOneWidget);
    expect(find.text('FLEET NAME'), findsOneWidget);
    expect(find.text('(optional)'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('profile screen loads the account and shows Log Out', (
    tester,
  ) async {
    final api = _FakeAuthApi();
    await pumpScreen(
      tester,
      ProfileScreen(
        api: api,
        tokenStorage: _FakeTokenStorage('valid-token'),
        photoService: noPhoto(),
        notificationService: noNotifications(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crew Profile'), findsOneWidget);
    expect(find.text('Marcus Thorne'), findsOneWidget); // name field value
    expect(find.text('marcus@example.com'), findsOneWidget); // read-only email
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    // No photo saved yet: offers to add one, not change one.
    expect(find.text('Add Photo'), findsOneWidget);
    expect(find.text('Change Photo'), findsNothing);
  });

  testWidgets(
    'profile screen picking a photo switches Add Photo to Change Photo',
    (tester) async {
      // The sync variant: testWidgets runs its body in a FakeAsync zone,
      // which can't drive real OS-backed async I/O (the async
      // Directory.createTemp hangs here the same way isolate-based sqflite
      // did elsewhere in this suite) — sync file I/O is unaffected.
      final dir = Directory.systemTemp.createTempSync('profile_photo_ui_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final pickedFile = File('${dir.path}/picked.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final photoService = _FakePhotoService()..toPick = pickedFile;

      await pumpScreen(
        tester,
        ProfileScreen(
          api: _FakeAuthApi(),
          tokenStorage: _FakeTokenStorage('valid-token'),
          photoService: photoService,
          notificationService: noNotifications(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Photo'), findsOneWidget);

      await tester.tap(find.text('Add Photo'));
      await tester.pumpAndSettle();

      expect(find.text('Change Photo'), findsOneWidget);
      expect(find.text('Add Photo'), findsNothing);
    },
  );

  testWidgets('profile logout clears token and returns to Welcome', (
    tester,
  ) async {
    final storage = _FakeTokenStorage('valid-token');
    final api = _FakeAuthApi();
    await pumpScreen(
      tester,
      ProfileScreen(
        api: api,
        tokenStorage: storage,
        photoService: noPhoto(),
        notificationService: noNotifications(),
      ),
    );
    await tester.pumpAndSettle();
    // The profile photo picker at the top of the form can push "Log Out"
    // below the fold on the test surface — scroll it into view first.
    await tester.ensureVisible(find.text('Log Out'));
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 1);
    expect(storage.token, isNull); // token cleared
    expect(find.text('Embark'), findsOneWidget); // landed on Welcome
  });

  testWidgets('auth gate routes to dashboard when the token is valid', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      AuthGate(api: _FakeAuthApi(), tokenStorage: _FakeTokenStorage('valid')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeDashboardScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('auth gate routes to Welcome when no token is stored', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      AuthGate(api: _FakeAuthApi(), tokenStorage: _FakeTokenStorage(null)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Embark'), findsOneWidget);
  });

  testWidgets('auth gate clears a stale token and shows Welcome', (
    tester,
  ) async {
    final storage = _FakeTokenStorage('stale');
    await pumpScreen(
      tester,
      AuthGate(
        api: _FakeAuthApi(
          meFailure: const AuthApiException(
            'Session expired.',
            isAuthFailure: true,
          ),
        ),
        tokenStorage: storage,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(storage.token, isNull); // stale token cleared
  });
}

/// In-memory [AuthApi] stand-in: returns a fixed account, records logout calls,
/// never touches the network. [meFailure] makes [me] throw an auth failure, to
/// exercise the stale-token path.
class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.meFailure});

  int logoutCalls = 0;
  final AuthApiException? meFailure;

  static const _account = Account(
    id: 1,
    name: 'Marcus Thorne',
    email: 'marcus@example.com',
    age: 34,
    sex: 'male',
    fleetName: 'Northern Fleet',
    createdAt: '2026-10-23T00:00:00+00:00',
  );

  @override
  Future<Account> me(String token) async {
    if (meFailure != null) throw meFailure!;
    return _account;
  }

  @override
  Future<Account> updateProfile(
    String token, {
    String? name,
    int? age,
    String? sex,
    String? fleetName,
  }) async => _account;

  @override
  Future<void> logout(String token) async => logoutCalls++;
}

/// In-memory [AuthTokenStorage] stand-in backed by a plain field.
class _FakeTokenStorage extends AuthTokenStorage {
  _FakeTokenStorage(this.token);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

/// In-memory [ProfilePhotoService] stand-in — avoids the real
/// path_provider/image_picker platform channels, which have no mock
/// registered in widget tests and would otherwise hang under pumpAndSettle.
class _FakePhotoService extends ProfilePhotoService {
  File? current;

  /// What the next [pickFromGallery] call returns (and becomes [current]).
  File? toPick;

  @override
  Future<File?> currentPhoto() async => current;

  @override
  Future<File?> pickFromGallery() async {
    if (toPick != null) current = toPick;
    return toPick;
  }
}

/// No-op stand-in — the real `LocalNotificationService` hits a plugin
/// platform channel with no mock handler registered in widget tests.
class _FakeNotificationService implements NotificationService {
  @override
  Future<void> initialize({
    void Function(NotificationTarget target)? onNotificationTap,
  }) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> showSignupWelcome() async {}

  @override
  Future<void> scheduleDailyReminders() async {}

  @override
  Future<void> cancelAll() async {}
}
