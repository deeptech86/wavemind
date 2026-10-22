import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/db/app_database.dart';
import 'content_api.dart';
import 'models/catalog_models.dart';

/// The resolved audio source for a story / sound: either a downloaded file on
/// this device, or a bundled `assets/audio/*` asset used as the permanent
/// offline fallback.
class ResolvedAudio {
  const ResolvedAudio({required this.path, required this.isLocalFile});

  /// Absolute file path (when [isLocalFile]) or a bundled asset path.
  final String path;

  /// True -> play via `AudioPlayer.setFilePath`; false -> `setAsset`.
  final bool isLocalFile;
}

/// On-device cache + access layer for the schedule-controlled content catalog
/// (rotating stories / soundscapes + which games are featured).
///
/// Design mirrors [WellnessRepository]: every public method is defensive. A
/// missing backend, missing native SQLite (widget tests), or missing
/// path_provider plugin never throws — reads return cached-or-empty and media
/// resolution falls back to the bundled asset. Content sync is strictly
/// best-effort so the app's calming features never depend on connectivity.
class ContentCatalogRepository {
  ContentCatalogRepository({ContentApi? api, AppDatabase? db})
    : _api = api ?? ContentApi(),
      _appDb = db ?? AppDatabase.instance;

  final ContentApi _api;
  final AppDatabase _appDb;

  static const String _mediaDirName = 'content_media';

  // --- Reads ----------------------------------------------------------------

  /// Load the locally-cached catalog. Returns [ContentCatalog.empty] when
  /// nothing has ever synced (fresh install / offline) — callers then fall
  /// back to the bundled content.
  Future<ContentCatalog> loadCached() {
    return _guard<ContentCatalog>(() async {
      final db = await _appDb.database;
      final storyRows = await db.query(
        'catalog_stories',
        where: 'active = 1',
        orderBy: 'sort_order, id',
      );
      final soundRows = await db.query(
        'catalog_sounds',
        where: 'active = 1',
        orderBy: 'sort_order, id',
      );
      final gameRows = await db.query(
        'catalog_featured_games',
        where: 'active = 1',
        orderBy: 'sort_order, game_key',
      );
      return ContentCatalog(
        stories: storyRows.map(CatalogStory.fromMap).toList(),
        sounds: soundRows.map(CatalogSound.fromMap).toList(),
        featuredGames: gameRows.map(FeaturedGame.fromMap).toList(),
      );
    }, fallback: ContentCatalog.empty);
  }

  // --- Sync -----------------------------------------------------------------

  /// Fetch `/content/catalog`, reconcile the local media cache (evicting files
  /// for anything no longer active or whose version changed), upsert the cache
  /// tables, and return the freshly-cached catalog. Returns `null` if the
  /// backend was unreachable / the sync failed — the caller keeps showing
  /// whatever it already had (cached or bundled).
  Future<ContentCatalog?> sync() async {
    ContentCatalog remote;
    try {
      remote = await _api.fetchCatalog();
    } on ContentApiException catch (e) {
      debugPrint('ContentCatalogRepository: sync skipped ($e)');
      return null;
    } catch (e) {
      debugPrint('ContentCatalogRepository: sync skipped ($e)');
      return null;
    }

    return _guard<ContentCatalog?>(() async {
      final db = await _appDb.database;

      // Snapshot what we currently have cached (all rows, any active state) so
      // we can decide which downloaded files survive the new catalog.
      final prevStories = (await db.query('catalog_stories'))
          .map(CatalogStory.fromMap)
          .toList();
      final prevSounds = (await db.query('catalog_sounds'))
          .map(CatalogSound.fromMap)
          .toList();

      final storyDecision = planMediaCache(
        previous: [
          for (final s in prevStories)
            CachedMediaRef(
              id: s.id,
              version: s.mediaVersion,
              localPath: s.localPath,
            ),
        ],
        incoming: [
          for (final s in remote.stories)
            IncomingMediaRef(id: s.id, version: s.mediaVersion),
        ],
      );
      final soundDecision = planMediaCache(
        previous: [
          for (final s in prevSounds)
            CachedMediaRef(
              id: s.id,
              version: s.mediaVersion,
              localPath: s.localPath,
            ),
        ],
        incoming: [
          for (final s in remote.sounds)
            IncomingMediaRef(id: s.id, version: s.mediaVersion),
        ],
      );

      // Delete the downloaded files that are no longer wanted. Never touches
      // bundled assets (those aren't files on disk — they ship in the app).
      for (final path in [
        ...storyDecision.filesToEvict,
        ...soundDecision.filesToEvict,
      ]) {
        _deleteFileQuietly(path);
      }

      // The catalog carries only active items, so a full replace keeps the
      // cache in exact lock-step with the server. Preserve still-valid local
      // paths (unchanged version) so an already-downloaded file isn't lost.
      final prevStoryById = {for (final s in prevStories) s.id: s};
      final prevSoundById = {for (final s in prevSounds) s.id: s};

      await db.transaction((txn) async {
        await txn.delete('catalog_stories');
        for (final s in remote.stories) {
          final keptPath = storyDecision.preservedLocalPaths[s.id];
          final kept = keptPath != null
              ? s.copyWith(
                  localPath: keptPath,
                  downloadedAt: prevStoryById[s.id]?.downloadedAt,
                )
              : s;
          await txn.insert('catalog_stories', kept.toMap());
        }

        await txn.delete('catalog_sounds');
        for (final s in remote.sounds) {
          final keptPath = soundDecision.preservedLocalPaths[s.id];
          final kept = keptPath != null
              ? s.copyWith(
                  localPath: keptPath,
                  downloadedAt: prevSoundById[s.id]?.downloadedAt,
                )
              : s;
          await txn.insert('catalog_sounds', kept.toMap());
        }

        await txn.delete('catalog_featured_games');
        for (final g in remote.featuredGames) {
          await txn.insert('catalog_featured_games', g.toMap());
        }
      });

      return loadCached();
    }, fallback: null);
  }

  // --- Lazy media resolution ------------------------------------------------

  /// Resolve a story's audio for playback. Returns a downloaded local file if
  /// one is present (downloading it lazily on first play), otherwise falls
  /// back to the supplied bundled asset so playback is never empty.
  Future<ResolvedAudio> resolveStoryAudio({
    required String id,
    required String mediaUrl,
    required String bundledAsset,
  }) {
    return _resolveMedia(
      table: 'catalog_stories',
      idColumn: 'id',
      id: id,
      filePrefix: 'story',
      mediaUrl: mediaUrl,
      bundledAsset: bundledAsset,
    );
  }

  /// Resolve a soundscape's audio for playback (see [resolveStoryAudio]).
  Future<ResolvedAudio> resolveSoundAudio({
    required String id,
    required String mediaUrl,
    required String bundledAsset,
  }) {
    return _resolveMedia(
      table: 'catalog_sounds',
      idColumn: 'id',
      id: id,
      filePrefix: 'sound',
      mediaUrl: mediaUrl,
      bundledAsset: bundledAsset,
    );
  }

  Future<ResolvedAudio> _resolveMedia({
    required String table,
    required String idColumn,
    required String id,
    required String filePrefix,
    required String mediaUrl,
    required String bundledAsset,
  }) async {
    final fallback = ResolvedAudio(path: bundledAsset, isLocalFile: false);
    if (mediaUrl.isEmpty) return fallback;

    final resolved = await _guard<ResolvedAudio?>(() async {
      final db = await _appDb.database;
      final rows = await db.query(
        table,
        where: '$idColumn = ?',
        whereArgs: [id],
        limit: 1,
      );

      // Reuse an already-downloaded file if it still exists on disk.
      if (rows.isNotEmpty) {
        final existing = rows.first['local_path'] as String?;
        if (existing != null &&
            existing.isNotEmpty &&
            File(existing).existsSync()) {
          return ResolvedAudio(path: existing, isLocalFile: true);
        }
      }

      // Lazily download into app-local storage.
      final bytes = await _api.downloadMedia(mediaUrl);
      final dir = await _mediaDir();
      final ext = _extensionFor(mediaUrl);
      final file = File(p.join(dir.path, '${filePrefix}_$id$ext'));
      await file.writeAsBytes(bytes, flush: true);

      await db.update(
        table,
        {
          'local_path': file.path,
          'downloaded_at': DateTime.now().toIso8601String(),
        },
        where: '$idColumn = ?',
        whereArgs: [id],
      );
      return ResolvedAudio(path: file.path, isLocalFile: true);
    }, fallback: null);

    return resolved ?? fallback;
  }

  // --- Internals ------------------------------------------------------------

  Future<Directory> _mediaDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _mediaDirName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static String _extensionFor(String mediaUrl) {
    try {
      final ext = p.extension(Uri.parse(mediaUrl).path);
      return ext.isNotEmpty ? ext : '';
    } catch (_) {
      return '';
    }
  }

  void _deleteFileQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (e) {
      debugPrint('ContentCatalogRepository: could not evict $path ($e)');
    }
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    required T fallback,
  }) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('ContentCatalogRepository: degrading to fallback ($e)');
      return fallback;
    }
  }

  void dispose() => _api.dispose();
}
