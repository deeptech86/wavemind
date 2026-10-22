import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'models/catalog_models.dart';

/// Thrown for any failure talking to the content catalog backend. Callers are
/// expected to catch this and fall back to cached / bundled content rather
/// than surfacing it as a hard error — content sync is strictly best-effort.
class ContentApiException implements Exception {
  const ContentApiException(this.message);
  final String message;

  @override
  String toString() => 'ContentApiException: $message';
}

/// Thin HTTP client for the content catalog service. Mirrors [ProfileApi]'s
/// posture: short timeouts, typed failures, and no assumption that the backend
/// is reachable (this is a sailing app — connectivity is unreliable by theme).
class ContentApi {
  ContentApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _catalogEndpoint => Uri.parse('${AppConfig.baseUrl}/content/catalog');

  /// Builds a full media URL from a catalog `mediaUrl` path (e.g.
  /// `/media/stories/lighthouse.m4a`). Absolute URLs are returned unchanged.
  Uri mediaUri(String mediaUrl) {
    if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
      return Uri.parse(mediaUrl);
    }
    return Uri.parse('${AppConfig.baseUrl}$mediaUrl');
  }

  /// Fetch the active content catalog. Throws [ContentApiException] on any
  /// transport or decoding failure.
  Future<ContentCatalog> fetchCatalog() async {
    final http.Response res;
    try {
      res = await _client
          .get(_catalogEndpoint, headers: const {'Accept': 'application/json'})
          .timeout(AppConfig.requestTimeout);
    } catch (_) {
      throw const ContentApiException('Could not reach the content service.');
    }
    if (res.statusCode != 200) {
      throw ContentApiException('Server error (${res.statusCode}).');
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Expected a JSON object');
      }
      return ContentCatalog.fromJson(decoded);
    } catch (_) {
      throw const ContentApiException('Received an unexpected catalog.');
    }
  }

  /// Download a media file's bytes. Throws [ContentApiException] on failure.
  Future<Uint8List> downloadMedia(String mediaUrl) async {
    final http.Response res;
    try {
      res = await _client
          .get(mediaUri(mediaUrl))
          .timeout(AppConfig.mediaDownloadTimeout);
    } catch (_) {
      throw const ContentApiException('Could not download media.');
    }
    if (res.statusCode != 200) {
      throw ContentApiException('Media error (${res.statusCode}).');
    }
    if (res.bodyBytes.isEmpty) {
      throw const ContentApiException('Downloaded media was empty.');
    }
    return res.bodyBytes;
  }

  void dispose() => _client.close();
}
