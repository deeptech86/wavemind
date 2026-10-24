import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tidewell_app/data/auth_api.dart';
import 'package:tidewell_app/data/auth_token_storage.dart';
import 'package:tidewell_app/data/crew_message_service.dart';
import 'package:tidewell_app/data/crew_mood_service.dart';
import 'package:tidewell_app/data/leaderboard_service.dart';
import 'package:tidewell_app/screens/community_connect_screen.dart';

/// Routes each request to a canned [http.Response] by (method, path), so one
/// client can stand in for the whole backend across the screen's several
/// concurrent syncs (leaderboard, mood, crew message).
class _RoutingClient extends http.BaseClient {
  _RoutingClient(this.responses);

  final Map<String, http.Response> responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key = '${request.method} ${request.url.path}';
    final response = responses[key] ?? http.Response('{}', 404);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _FixedTokenStorage extends AuthTokenStorage {
  _FixedTokenStorage(this._token);
  final String? _token;

  @override
  Future<String?> read() async => _token;
}

void main() {
  testWidgets(
    'Anchor Pool shows the real crew swell % and the latest cast message',
    (tester) async {
      final client = _RoutingClient({
        'GET /leaderboard': http.Response(jsonEncode({'entries': []}), 200),
        'GET /crew/mood-summary': http.Response(
          jsonEncode({'calm_percent': 75, 'total_logged': 4}),
          200,
        ),
        'GET /crew/message': http.Response(
          jsonEncode({
            'messages': [
              {
                'id': 1,
                'body': 'Fair winds to the night watch.',
                'author_name': 'Elena Reyes',
                'posted_at': '2026-01-01T00:00:00+00:00',
                'flagged_by_me': false,
              },
            ],
          }),
          200,
        ),
      });
      final api = AuthApi(client: client);
      final tokenStorage = _FixedTokenStorage('tok');

      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityConnectScreen(
            initialTab: CrewTab.anchorPool,
            leaderboardService: LeaderboardService(
              api: api,
              tokenStorage: tokenStorage,
            ),
            crewMoodService: CrewMoodService(
              api: api,
              tokenStorage: tokenStorage,
            ),
            crewMessageService: CrewMessageService(
              api: api,
              tokenStorage: tokenStorage,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Calm or Steady Winds'), findsOneWidget);
      expect(find.text('Fair winds to the night watch.'), findsOneWidget);
      expect(find.text('Elena Reyes'), findsOneWidget);
    },
  );

  testWidgets(
    'casting a 4th message bumps the oldest of 3 off and shifts the rest down',
    (tester) async {
      // Already at the 3-message cap: casting a 4th should evict "Oldest
      // cast." while "Middle cast." and "Newest cast." both shift down a
      // slot, same as the real backend's prune-to-3 behavior.
      final initialMessages = [
        {
          'id': 3,
          'body': 'Newest cast.',
          'author_name': 'Marcus Thorne',
          'posted_at': '2026-01-03T00:00:00+00:00',
          'flagged_by_me': false,
        },
        {
          'id': 2,
          'body': 'Middle cast.',
          'author_name': 'Marcus Thorne',
          'posted_at': '2026-01-02T00:00:00+00:00',
          'flagged_by_me': false,
        },
        {
          'id': 1,
          'body': 'Oldest cast.',
          'author_name': 'Marcus Thorne',
          'posted_at': '2026-01-01T00:00:00+00:00',
          'flagged_by_me': false,
        },
      ];
      final client = _RoutingClient({
        'GET /leaderboard': http.Response(jsonEncode({'entries': []}), 200),
        'GET /crew/mood-summary': http.Response(
          jsonEncode({'calm_percent': 0, 'total_logged': 0}),
          200,
        ),
      });
      // The crew-message endpoints need stateful behavior (PUT prepends to
      // what the next GET returns, same as the real backend), so handle them
      // with a small custom client rather than the static _RoutingClient.
      final crewMessageClient = _StatefulCrewMessageClient(
        initial: initialMessages,
        fallback: client,
      );
      final api = AuthApi(client: crewMessageClient);
      final tokenStorage = _FixedTokenStorage('tok');

      // Wide enough that all 3 cards in the horizontal Gratitude Wall list
      // are actually built (ListView lazily builds only what's on/near
      // screen), so find.text can see every card without scrolling.
      await tester.binding.setSurfaceSize(const Size(900, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityConnectScreen(
            initialTab: CrewTab.anchorPool,
            leaderboardService: LeaderboardService(
              api: api,
              tokenStorage: tokenStorage,
            ),
            crewMoodService: CrewMoodService(
              api: api,
              tokenStorage: tokenStorage,
            ),
            crewMessageService: CrewMessageService(
              api: api,
              tokenStorage: tokenStorage,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Newest cast.'), findsOneWidget);
      expect(find.text('Middle cast.'), findsOneWidget);
      expect(find.text('Oldest cast.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A brand new cast.');
      await tester.pump();
      await tester.tap(find.text('Cast to Fleet'));
      await tester.pump(); // start posting
      await tester.pump(); // PUT resolves
      await tester.pump(); // refetch GET resolves

      // The new cast leads; "Newest cast." and "Middle cast." both shifted
      // down a slot; "Oldest cast." fell off past the 3-message cap.
      expect(find.text('A brand new cast.'), findsOneWidget);
      expect(find.text('Newest cast.'), findsOneWidget);
      expect(find.text('Middle cast.'), findsOneWidget);
      expect(find.text('Oldest cast.'), findsNothing);
    },
  );

  testWidgets('flagging a message disables its flag button once recorded', (
    tester,
  ) async {
    final messageClient = _StatefulFlagClient(
      message: {
        'id': 1,
        'body': 'A message worth flagging.',
        'author_name': 'Someone Else',
        'posted_at': '2026-01-01T00:00:00+00:00',
      },
    );
    final client = _RoutingClient({
      'GET /leaderboard': http.Response(jsonEncode({'entries': []}), 200),
      'GET /crew/mood-summary': http.Response(
        jsonEncode({'calm_percent': 0, 'total_logged': 0}),
        200,
      ),
    });
    final api = AuthApi(
      client: _FallbackClient(primary: messageClient, fallback: client),
    );
    final tokenStorage = _FixedTokenStorage('tok');

    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityConnectScreen(
          initialTab: CrewTab.anchorPool,
          leaderboardService: LeaderboardService(
            api: api,
            tokenStorage: tokenStorage,
          ),
          crewMoodService: CrewMoodService(
            api: api,
            tokenStorage: tokenStorage,
          ),
          crewMessageService: CrewMessageService(
            api: api,
            tokenStorage: tokenStorage,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsNothing);

    final flagButton = find.byIcon(Icons.flag_outlined);

    await tester.tap(flagButton);
    await tester.pump(); // POST resolves
    await tester.pump(); // refetch GET resolves

    expect(find.byIcon(Icons.flag_outlined), findsNothing);
    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(messageClient.flagCount, 1);
  });

  testWidgets('a suspended account sees a notice instead of the compose box', (
    tester,
  ) async {
    final client = _RoutingClient({
      'GET /leaderboard': http.Response(jsonEncode({'entries': []}), 200),
      'GET /crew/mood-summary': http.Response(
        jsonEncode({'calm_percent': 0, 'total_logged': 0}),
        200,
      ),
      'GET /crew/message': http.Response(
        jsonEncode({
          'messages': [],
          'my_suspended_until': '2026-11-23T00:00:00+00:00',
        }),
        200,
      ),
    });
    final api = AuthApi(client: client);
    final tokenStorage = _FixedTokenStorage('tok');

    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityConnectScreen(
          initialTab: CrewTab.anchorPool,
          leaderboardService: LeaderboardService(
            api: api,
            tokenStorage: tokenStorage,
          ),
          crewMoodService: CrewMoodService(
            api: api,
            tokenStorage: tokenStorage,
          ),
          crewMessageService: CrewMessageService(
            api: api,
            tokenStorage: tokenStorage,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Casting is paused until Nov 23, 2026'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Cast to Fleet'), findsNothing);
  });
}

/// Delegates to [primary] for crew-message requests, else [fallback].
class _FallbackClient extends http.BaseClient {
  _FallbackClient({required this.primary, required this.fallback});

  final http.BaseClient primary;
  final http.BaseClient fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.startsWith('/crew/message')) {
      return primary.send(request);
    }
    return fallback.send(request);
  }
}

/// A single crew message that can be flagged, toggling `flagged_by_me` on
/// the next GET — mirrors the real backend's per-caller flag state.
class _StatefulFlagClient extends http.BaseClient {
  _StatefulFlagClient({required this.message});

  final Map<String, Object?> message;
  int flagCount = 0;
  bool _flaggedByMe = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/flag')) {
      flagCount++;
      _flaggedByMe = true;
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({'flag_count': flagCount, 'author_suspended': false}),
          ),
        ),
        200,
      );
    }
    if (request.method == 'GET' && request.url.path == '/crew/message') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'messages': [
                {...message, 'flagged_by_me': _flaggedByMe},
              ],
            }),
          ),
        ),
        200,
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }
}

/// Mirrors the real backend's PUT-prepends/GET-wraps-in-"messages" behavior
/// for /crew/message, capped at 3 — the static _RoutingClient can't express
/// state that changes between calls.
class _StatefulCrewMessageClient extends http.BaseClient {
  _StatefulCrewMessageClient({
    required List<Map<String, Object?>> initial,
    required http.BaseClient fallback,
  }) : messages = initial,
       _fallback = fallback;

  List<Map<String, Object?>> messages;
  final http.BaseClient _fallback;
  int _nextId = 100;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/crew/message' && request.method == 'PUT') {
      final body = jsonDecode((request as http.Request).body) as Map;
      final posted = {
        'id': _nextId++,
        'body': body['body'],
        'author_name': 'Marcus Thorne',
        'posted_at': '2026-01-02T00:00:00+00:00',
        'flagged_by_me': false,
      };
      messages = [posted, ...messages].take(3).toList();
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(posted))),
        200,
      );
    }
    if (request.url.path == '/crew/message' && request.method == 'GET') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'messages': messages}))),
        200,
      );
    }
    return _fallback.send(request);
  }
}
