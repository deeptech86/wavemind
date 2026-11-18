import 'dart:convert';

/// Identifiers for the seven built-in off-watch games. These are the only
/// values the server's `featured_game.game_key` may take, and they must match
/// the tiles rendered in `off_watch_games_screen.dart` and the seed on the
/// backend (`backend/app/seed.py`). No new game *content* ever flows through
/// the catalog — only which of these are spotlighted this week.
abstract final class GameKeys {
  static const String calmYourWaves = 'calm_your_waves';
  static const String knotMaster = 'knot_master';
  static const String fogSignalEcho = 'fog_signal_echo';
  static const String sextantHorizon = 'sextant_horizon';
  static const String cabinDominoes = 'cabin_dominoes';
  static const String stoneCairn = 'stone_cairn';
  static const String matchstickPuzzle = 'matchstick_puzzle';

  static const List<String> all = [
    calmYourWaves,
    knotMaster,
    fogSignalEcho,
    sextantHorizon,
    cabinDominoes,
    stoneCairn,
    matchstickPuzzle,
  ];
}

/// A cached narrated-story catalog row. Mirrors the server shape plus local
/// bookkeeping (`localPath`, `downloadedAt`) so a downloaded media file is
/// reused on repeat plays and survives offline.
///
/// Only media + core teaser copy + the active flag are server-driven; the
/// richer presentation (vibe chips, chapter copy) stays client-authored,
/// keyed by [id].
class CatalogStory {
  const CatalogStory({
    required this.id,
    required this.title,
    required this.series,
    required this.narrator,
    required this.teaserSubtitle,
    required this.excerpt,
    required this.coordinates,
    required this.swellNote,
    required this.durationLabel,
    required this.mediaUrl,
    required this.mediaVersion,
    required this.sortOrder,
    required this.active,
    this.localPath,
    this.downloadedAt,
  });

  final String id;
  final String title;
  final String series;
  final String narrator;
  final String teaserSubtitle;
  final List<String> excerpt;
  final String coordinates;
  final String swellNote;
  final String durationLabel;

  /// Server path (e.g. `/media/stories/lighthouse.m4a`); prefix with the API
  /// base URL to download.
  final String mediaUrl;

  /// Change-detection stamp; a changed value means the file must be re-fetched.
  final String mediaVersion;
  final int sortOrder;
  final bool active;

  /// Absolute path to the downloaded file on this device, or null if not
  /// downloaded yet.
  final String? localPath;
  final String? downloadedAt;

  CatalogStory copyWith({String? localPath, String? downloadedAt}) =>
      CatalogStory(
        id: id,
        title: title,
        series: series,
        narrator: narrator,
        teaserSubtitle: teaserSubtitle,
        excerpt: excerpt,
        coordinates: coordinates,
        swellNote: swellNote,
        durationLabel: durationLabel,
        mediaUrl: mediaUrl,
        mediaVersion: mediaVersion,
        sortOrder: sortOrder,
        active: active,
        localPath: localPath ?? this.localPath,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );

  factory CatalogStory.fromCatalogJson(Map<String, Object?> json) {
    final rawExcerpt = json['excerpt'];
    return CatalogStory(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      series: json['series'] as String? ?? '',
      narrator: json['narrator'] as String? ?? '',
      teaserSubtitle: json['teaser_subtitle'] as String? ?? '',
      excerpt: rawExcerpt is List
          ? rawExcerpt.map((e) => e.toString()).toList()
          : const [],
      coordinates: json['coordinates'] as String? ?? '',
      swellNote: json['swell_note'] as String? ?? '',
      durationLabel: json['duration_label'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String? ?? '',
      mediaVersion: json['mediaVersion'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'series': series,
    'narrator': narrator,
    'teaser_subtitle': teaserSubtitle,
    'excerpt': jsonEncode(excerpt),
    'coordinates': coordinates,
    'swell_note': swellNote,
    'duration_label': durationLabel,
    'media_url': mediaUrl,
    'media_version': mediaVersion,
    'sort_order': sortOrder,
    'active': active ? 1 : 0,
    'local_path': localPath,
    'downloaded_at': downloadedAt,
  };

  factory CatalogStory.fromMap(Map<String, Object?> map) {
    final rawExcerpt = map['excerpt'] as String? ?? '[]';
    List<String> excerpt;
    try {
      final decoded = jsonDecode(rawExcerpt);
      excerpt = decoded is List
          ? decoded.map((e) => e.toString()).toList()
          : const [];
    } catch (_) {
      excerpt = const [];
    }
    return CatalogStory(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      series: map['series'] as String? ?? '',
      narrator: map['narrator'] as String? ?? '',
      teaserSubtitle: map['teaser_subtitle'] as String? ?? '',
      excerpt: excerpt,
      coordinates: map['coordinates'] as String? ?? '',
      swellNote: map['swell_note'] as String? ?? '',
      durationLabel: map['duration_label'] as String? ?? '',
      mediaUrl: map['media_url'] as String? ?? '',
      mediaVersion: map['media_version'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      active: (map['active'] as num?)?.toInt() == 1,
      localPath: map['local_path'] as String?,
      downloadedAt: map['downloaded_at'] as String?,
    );
  }
}

/// A cached ambient-soundscape catalog row.
class CatalogSound {
  const CatalogSound({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.mediaUrl,
    required this.mediaVersion,
    required this.sortOrder,
    required this.active,
    this.localPath,
    this.downloadedAt,
  });

  final String id;
  final String label;
  final String subtitle;
  final String mediaUrl;
  final String mediaVersion;
  final int sortOrder;
  final bool active;
  final String? localPath;
  final String? downloadedAt;

  CatalogSound copyWith({String? localPath, String? downloadedAt}) =>
      CatalogSound(
        id: id,
        label: label,
        subtitle: subtitle,
        mediaUrl: mediaUrl,
        mediaVersion: mediaVersion,
        sortOrder: sortOrder,
        active: active,
        localPath: localPath ?? this.localPath,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );

  factory CatalogSound.fromCatalogJson(Map<String, Object?> json) =>
      CatalogSound(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        mediaUrl: json['mediaUrl'] as String? ?? '',
        mediaVersion: json['mediaVersion'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'label': label,
    'subtitle': subtitle,
    'media_url': mediaUrl,
    'media_version': mediaVersion,
    'sort_order': sortOrder,
    'active': active ? 1 : 0,
    'local_path': localPath,
    'downloaded_at': downloadedAt,
  };

  factory CatalogSound.fromMap(Map<String, Object?> map) => CatalogSound(
    id: map['id'] as String? ?? '',
    label: map['label'] as String? ?? '',
    subtitle: map['subtitle'] as String? ?? '',
    mediaUrl: map['media_url'] as String? ?? '',
    mediaVersion: map['media_version'] as String? ?? '',
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    active: (map['active'] as num?)?.toInt() == 1,
    localPath: map['local_path'] as String?,
    downloadedAt: map['downloaded_at'] as String?,
  );
}

/// A spotlighted-game flag. No media / levels — just which built-in game key
/// is featured and in what order.
class FeaturedGame {
  const FeaturedGame({
    required this.gameKey,
    required this.active,
    required this.effectiveFrom,
    required this.sortOrder,
  });

  final String gameKey;
  final bool active;
  final String effectiveFrom;
  final int sortOrder;

  factory FeaturedGame.fromCatalogJson(Map<String, Object?> json) =>
      FeaturedGame(
        gameKey: json['game_key'] as String? ?? '',
        active: json['active'] as bool? ?? false,
        effectiveFrom: json['effective_from'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toMap() => {
    'game_key': gameKey,
    'active': active ? 1 : 0,
    'effective_from': effectiveFrom,
    'sort_order': sortOrder,
  };

  factory FeaturedGame.fromMap(Map<String, Object?> map) => FeaturedGame(
    gameKey: map['game_key'] as String? ?? '',
    active: (map['active'] as num?)?.toInt() == 1,
    effectiveFrom: map['effective_from'] as String? ?? '',
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
  );
}

/// The full catalog response from `GET /content/catalog`.
class ContentCatalog {
  const ContentCatalog({
    required this.stories,
    required this.sounds,
    required this.featuredGames,
  });

  final List<CatalogStory> stories;
  final List<CatalogSound> sounds;
  final List<FeaturedGame> featuredGames;

  static const empty = ContentCatalog(
    stories: [],
    sounds: [],
    featuredGames: [],
  );

  factory ContentCatalog.fromJson(Map<String, Object?> json) {
    List<T> parse<T>(Object? raw, T Function(Map<String, Object?>) fromJson) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, Object?>>()
          .map(fromJson)
          .toList();
    }

    return ContentCatalog(
      stories: parse(json['stories'], CatalogStory.fromCatalogJson),
      sounds: parse(json['sounds'], CatalogSound.fromCatalogJson),
      featuredGames: parse(json['featuredGames'], FeaturedGame.fromCatalogJson),
    );
  }
}

/// A lightweight reference to a cached media item for cache-planning: just the
/// identity, its locally-downloaded file path (if any) and its version.
class CachedMediaRef {
  const CachedMediaRef({
    required this.id,
    required this.version,
    this.localPath,
  });

  final String id;
  final String version;
  final String? localPath;
}

/// A lightweight reference to an incoming (server) media item for planning.
class IncomingMediaRef {
  const IncomingMediaRef({required this.id, required this.version});

  final String id;
  final String version;
}

/// The outcome of reconciling the previously-cached media against a fresh
/// catalog: which downloaded files to delete, and which existing local paths
/// to preserve (keyed by incoming id; a null value means "must re-download").
class MediaCacheDecision {
  const MediaCacheDecision({
    required this.filesToEvict,
    required this.preservedLocalPaths,
  });

  final List<String> filesToEvict;
  final Map<String, String?> preservedLocalPaths;
}

/// Pure reconciliation logic (no DB / filesystem) so it is unit-testable in
/// isolation. Decides, given the previously-cached items and the fresh catalog:
///
///   * Evict the downloaded file of any item that is no longer present (went
///     inactive / was removed), or whose version changed (stale file).
///   * Preserve a still-valid downloaded path (same id, same version) so an
///     unchanged file is never re-downloaded.
MediaCacheDecision planMediaCache({
  required List<CachedMediaRef> previous,
  required List<IncomingMediaRef> incoming,
}) {
  final incomingById = {for (final i in incoming) i.id: i};
  final previousById = {for (final p in previous) p.id: p};

  final filesToEvict = <String>[];

  // Items that dropped out of the catalog entirely -> evict their file.
  for (final prev in previous) {
    if (!incomingById.containsKey(prev.id) &&
        (prev.localPath != null && prev.localPath!.isNotEmpty)) {
      filesToEvict.add(prev.localPath!);
    }
  }

  final preserved = <String, String?>{};
  for (final inc in incoming) {
    final prev = previousById[inc.id];
    final hasFile = prev?.localPath != null && prev!.localPath!.isNotEmpty;
    if (prev != null && hasFile && prev.version == inc.version) {
      preserved[inc.id] = prev.localPath; // unchanged -> keep
    } else {
      preserved[inc.id] = null; // must (re)download
      if (prev != null && hasFile && prev.version != inc.version) {
        filesToEvict.add(prev.localPath!); // stale version -> evict old file
      }
    }
  }

  return MediaCacheDecision(
    filesToEvict: filesToEvict,
    preservedLocalPaths: preserved,
  );
}
