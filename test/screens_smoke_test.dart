import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/data/auth_api.dart';
import 'package:tidewell_app/data/auth_token_storage.dart';
import 'package:tidewell_app/data/crew_message_service.dart';
import 'package:tidewell_app/data/crew_mood_service.dart';
import 'package:tidewell_app/data/leaderboard_service.dart';
import 'package:tidewell_app/data/models/account.dart';
import 'package:tidewell_app/data/profile_photo_service.dart';
import 'package:tidewell_app/screens/auth_gate.dart';
import 'package:tidewell_app/screens/home_dashboard_screen.dart';
import 'package:tidewell_app/screens/login_screen.dart';
import 'package:tidewell_app/screens/profile_screen.dart';
import 'package:tidewell_app/screens/signup_screen.dart';
import 'package:tidewell_app/screens/welcome_screen.dart';
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
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Edit'));
    await tester.pump();
    expect(find.text('Voyage Details'), findsOneWidget);
  });

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
    await pumpScreen(tester, const HavenScreen());
    expect(find.text('Safe Haven'), findsOneWidget);
    expect(find.text('Tidal Breath'), findsOneWidget);
    // Off-Watch Mind Games moved here, between Sleep Lore and Ambient Sounds.
    expect(find.text('OFF-WATCH MIND GAMES'), findsOneWidget);
    expect(find.text('Celestial Wayfinder'), findsOneWidget);
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
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crew Profile'), findsOneWidget);
    expect(find.text('Marcus Thorne'), findsOneWidget); // name field value
    expect(find.text('marcus@example.com'), findsOneWidget); // read-only email
    expect(find.text('Save Crew Details'), findsOneWidget);
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
      ProfileScreen(api: api, tokenStorage: storage, photoService: noPhoto()),
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
