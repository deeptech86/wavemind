import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tidewell_app/data/auth_api.dart';
import 'package:tidewell_app/data/auth_token_storage.dart';
import 'package:tidewell_app/data/leaderboard_service.dart';

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

class _FixedTokenStorage extends AuthTokenStorage {
  _FixedTokenStorage(this._token);
  final String? _token;

  @override
  Future<String?> read() async => _token;
}

void main() {
  group('AuthApi.updatePoints', () {
    test('PUTs the whole current total to /me/points', () async {
      final client = _StubClient(
        http.Response(jsonEncode({'total_points': 500}), 200),
      );
      final api = AuthApi(client: client);

      await api.updatePoints('tok', 500);

      expect(client.lastRequest!.method, 'PUT');
      expect(client.lastRequest!.url.path, '/me/points');
      expect(
        client.lastRequest!.headers['Authorization'],
        'Bearer tok',
      );
      expect(jsonDecode(client.lastBody!), {'total_points': 500});
    });

    test('throws an auth failure on 401', () async {
      final client = _StubClient(http.Response('{}', 401));
      final api = AuthApi(client: client);

      expect(
        () => api.updatePoints('tok', 10),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.isAuthFailure,
            'isAuthFailure',
            true,
          ),
        ),
      );
    });
  });

  group('AuthApi.leaderboard', () {
    test('parses the entries list', () async {
      final body = jsonEncode({
        'entries': [
          {
            'name': 'Bosun Liam S.',
            'fleet_name': 'Northern Fleet',
            'total_points': 850,
            'rank': 1,
            'is_me': false,
          },
          {
            'name': 'Marcus Thorne',
            'fleet_name': null,
            'total_points': 320,
            'rank': 7,
            'is_me': true,
          },
        ],
      });
      final client = _StubClient(http.Response(body, 200));
      final api = AuthApi(client: client);

      final entries = await api.leaderboard('tok', limit: 4);

      expect(client.lastRequest!.method, 'GET');
      expect(client.lastRequest!.url.path, '/leaderboard');
      expect(client.lastRequest!.url.queryParameters['limit'], '4');
      expect(entries, hasLength(2));
      expect(entries[0].name, 'Bosun Liam S.');
      expect(entries[0].isMe, false);
      expect(entries[1].isMe, true);
      expect(entries[1].rank, 7);
    });
  });

  group('LeaderboardService.sync', () {
    test('returns null when there is no stored session', () async {
      final service = LeaderboardService(
        api: AuthApi(client: _StubClient(http.Response('{}', 200))),
        tokenStorage: _FixedTokenStorage(null),
      );

      expect(await service.sync(100), isNull);
    });

    test('pushes points then returns the fetched leaderboard', () async {
      final leaderboardBody = jsonEncode({
        'entries': [
          {
            'name': 'Marcus Thorne',
            'fleet_name': null,
            'total_points': 100,
            'rank': 1,
            'is_me': true,
          },
        ],
      });
      // One client answers both endpoints, routed by request path, so the
      // test can assert the push happens before the fetch.
      final client = _PathRoutingClient({
        '/me/points': http.Response(jsonEncode({'total_points': 100}), 200),
        '/leaderboard': http.Response(leaderboardBody, 200),
      });
      final service = LeaderboardService(
        api: AuthApi(client: client),
        tokenStorage: _FixedTokenStorage('tok'),
      );

      final entries = await service.sync(100);

      expect(entries, hasLength(1));
      expect(entries!.single.isMe, true);
      expect(entries.single.totalPoints, 100);
      expect(client.calledPaths, ['/me/points', '/leaderboard']);
    });
  });
}

/// Routes each request to a canned [http.Response] by URL path, recording
/// the call order so a test can assert the push happens before the fetch.
class _PathRoutingClient extends http.BaseClient {
  _PathRoutingClient(this.responses);

  final Map<String, http.Response> responses;
  final List<String> calledPaths = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    calledPaths.add(path);
    final response = responses[path]!;
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}
