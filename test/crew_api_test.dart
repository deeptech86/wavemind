import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tidewell_app/data/auth_api.dart';
import 'package:tidewell_app/data/auth_token_storage.dart';
import 'package:tidewell_app/data/crew_message_service.dart';
import 'package:tidewell_app/data/crew_mood_service.dart';
import 'package:tidewell_app/data/models/mood_state.dart';

/// Records the request it received and always returns [response].
class _StubClient extends http.BaseClient {
  _StubClient(this.response);

  final http.Response response;
  http.BaseRequest? lastRequest;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request) lastBody = request.body;
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

/// Routes each request to a canned [http.Response] by (method, path).
class _RoutingClient extends http.BaseClient {
  _RoutingClient(this.responses);

  final Map<String, http.Response> responses;
  final List<String> calledKeys = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key = '${request.method} ${request.url.path}';
    calledKeys.add(key);
    final response = responses[key]!;
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
  group('AuthApi.updateMood', () {
    test('PUTs the mood state key to /me/mood', () async {
      final client = _StubClient(http.Response(jsonEncode({'state': 'calm_sea'}), 200));
      final api = AuthApi(client: client);

      await api.updateMood('tok', MoodState.calmSea);

      expect(client.lastRequest!.method, 'PUT');
      expect(client.lastRequest!.url.path, '/me/mood');
      expect(jsonDecode(client.lastBody!), {'state': 'calm_sea'});
    });
  });

  group('AuthApi.crewMoodSummary', () {
    test('parses the aggregate', () async {
      final body = jsonEncode({'calm_percent': 75, 'total_logged': 8});
      final client = _StubClient(http.Response(body, 200));
      final api = AuthApi(client: client);

      final summary = await api.crewMoodSummary('tok');

      expect(client.lastRequest!.method, 'GET');
      expect(client.lastRequest!.url.path, '/crew/mood-summary');
      expect(summary.calmPercent, 75);
      expect(summary.totalLogged, 8);
    });
  });

  group('AuthApi.postCrewMessage / crewMessage', () {
    test('posts the body and parses the response', () async {
      final body = jsonEncode({
        'body': 'Fair winds.',
        'author_name': 'Marcus Thorne',
        'posted_at': '2026-01-01T00:00:00+00:00',
      });
      final client = _StubClient(http.Response(body, 200));
      final api = AuthApi(client: client);

      final message = await api.postCrewMessage('tok', 'Fair winds.');

      expect(client.lastRequest!.method, 'PUT');
      expect(client.lastRequest!.url.path, '/crew/message');
      expect(jsonDecode(client.lastBody!), {'body': 'Fair winds.'});
      expect(message.body, 'Fair winds.');
      expect(message.authorName, 'Marcus Thorne');
    });

    test('crewMessages parses the list, newest first, plus suspension', () async {
      final body = jsonEncode({
        'messages': [
          {
            'id': 2,
            'body': 'Second cast.',
            'author_name': 'Bob',
            'posted_at': '2026-01-02T00:00:00+00:00',
            'flagged_by_me': true,
          },
          {
            'id': 1,
            'body': 'First cast.',
            'author_name': 'Alice',
            'posted_at': '2026-01-01T00:00:00+00:00',
            'flagged_by_me': false,
          },
        ],
        'my_suspended_until': '2026-02-01T00:00:00+00:00',
      });
      final client = _StubClient(http.Response(body, 200));
      final api = AuthApi(client: client);

      final page = await api.crewMessages('tok');

      expect(page.messages, hasLength(2));
      expect(page.messages[0].body, 'Second cast.');
      expect(page.messages[0].id, 2);
      expect(page.messages[0].flaggedByMe, true);
      expect(page.messages[1].body, 'First cast.');
      expect(page.mySuspendedUntil, DateTime.parse('2026-02-01T00:00:00+00:00'));
    });

    test('crewMessages returns an empty list when none have been cast', () async {
      final client = _StubClient(http.Response(jsonEncode({'messages': []}), 200));
      final api = AuthApi(client: client);

      expect((await api.crewMessages('tok')).messages, isEmpty);
    });
  });

  group('AuthApi.flagCrewMessage', () {
    test('POSTs to the flag endpoint', () async {
      final client = _StubClient(http.Response(jsonEncode({'flag_count': 1, 'author_suspended': false}), 200));
      final api = AuthApi(client: client);

      await api.flagCrewMessage('tok', 42);

      expect(client.lastRequest!.method, 'POST');
      expect(client.lastRequest!.url.path, '/crew/message/42/flag');
    });

    test('throws on a 404 (message aged out)', () async {
      final client = _StubClient(http.Response('{}', 404));
      final api = AuthApi(client: client);

      expect(
        () => api.flagCrewMessage('tok', 999),
        throwsA(isA<AuthApiException>()),
      );
    });
  });

  group('CrewMoodService.sync', () {
    test('returns null when there is no stored session', () async {
      final service = CrewMoodService(
        api: AuthApi(client: _StubClient(http.Response('{}', 200))),
        tokenStorage: _FixedTokenStorage(null),
      );

      expect(await service.sync(MoodState.calmSea), isNull);
    });

    test('skips the push when there is no local mood yet, still fetches', () async {
      final client = _RoutingClient({
        'GET /crew/mood-summary': http.Response(
          jsonEncode({'calm_percent': 0, 'total_logged': 0}),
          200,
        ),
      });
      final service = CrewMoodService(
        api: AuthApi(client: client),
        tokenStorage: _FixedTokenStorage('tok'),
      );

      final summary = await service.sync(null);

      expect(summary!.totalLogged, 0);
      expect(client.calledKeys, ['GET /crew/mood-summary']);
    });

    test('pushes the local mood before fetching the summary', () async {
      final client = _RoutingClient({
        'PUT /me/mood': http.Response(jsonEncode({'state': 'calm_sea'}), 200),
        'GET /crew/mood-summary': http.Response(
          jsonEncode({'calm_percent': 100, 'total_logged': 1}),
          200,
        ),
      });
      final service = CrewMoodService(
        api: AuthApi(client: client),
        tokenStorage: _FixedTokenStorage('tok'),
      );

      final summary = await service.sync(MoodState.calmSea);

      expect(summary!.calmPercent, 100);
      expect(client.calledKeys, ['PUT /me/mood', 'GET /crew/mood-summary']);
    });
  });

  group('CrewMessageService', () {
    test('fetchLatest returns null when there is no stored session', () async {
      final service = CrewMessageService(
        api: AuthApi(client: _StubClient(http.Response('null', 200))),
        tokenStorage: _FixedTokenStorage(null),
      );

      expect(await service.fetchLatest(), isNull);
    });

    test('fetchLatest returns the real page when a session exists', () async {
      final body = jsonEncode({
        'messages': [
          {
            'id': 1,
            'body': 'Fair winds.',
            'author_name': 'Marcus Thorne',
            'posted_at': '2026-01-01T00:00:00+00:00',
            'flagged_by_me': false,
          },
        ],
      });
      final service = CrewMessageService(
        api: AuthApi(client: _StubClient(http.Response(body, 200))),
        tokenStorage: _FixedTokenStorage('tok'),
      );

      final page = await service.fetchLatest();

      expect(page!.messages, hasLength(1));
      expect(page.messages.single.authorName, 'Marcus Thorne');
      expect(page.mySuspendedUntil, isNull);
    });

    test('flag throws when there is no stored session', () async {
      final service = CrewMessageService(
        api: AuthApi(client: _StubClient(http.Response('{}', 200))),
        tokenStorage: _FixedTokenStorage(null),
      );

      expect(() => service.flag(1), throwsA(isA<AuthApiException>()));
    });

    test('flag calls through to the API when a session exists', () async {
      final client = _StubClient(
        http.Response(jsonEncode({'flag_count': 1, 'author_suspended': false}), 200),
      );
      final service = CrewMessageService(
        api: AuthApi(client: client),
        tokenStorage: _FixedTokenStorage('tok'),
      );

      await service.flag(7);

      expect(client.lastRequest!.url.path, '/crew/message/7/flag');
    });

    test('cast throws when there is no stored session', () async {
      final service = CrewMessageService(
        api: AuthApi(client: _StubClient(http.Response('{}', 200))),
        tokenStorage: _FixedTokenStorage(null),
      );

      expect(() => service.cast('hi'), throwsA(isA<AuthApiException>()));
    });

    test('cast posts via the API when a session exists', () async {
      final body = jsonEncode({
        'body': 'Hold fast.',
        'author_name': 'Marcus Thorne',
        'posted_at': '2026-01-01T00:00:00+00:00',
      });
      final client = _StubClient(http.Response(body, 200));
      final service = CrewMessageService(
        api: AuthApi(client: client),
        tokenStorage: _FixedTokenStorage('tok'),
      );

      final message = await service.cast('Hold fast.');

      expect(message.body, 'Hold fast.');
      expect(client.lastRequest!.url.path, '/crew/message');
    });
  });
}
