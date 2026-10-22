import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/data/models/catalog_models.dart';
import 'package:tidewell_app/screens/story_playback_screen.dart';

void main() {
  group('planMediaCache — eviction & preservation', () {
    test('evicts the downloaded file of an item no longer in the catalog', () {
      final decision = planMediaCache(
        previous: const [
          CachedMediaRef(id: 'a', version: 'v1', localPath: '/m/a.m4a'),
          CachedMediaRef(id: 'b', version: 'v1', localPath: '/m/b.m4a'),
        ],
        incoming: const [IncomingMediaRef(id: 'a', version: 'v1')],
      );
      // b dropped out -> its file is evicted; a is unchanged -> preserved.
      expect(decision.filesToEvict, ['/m/b.m4a']);
      expect(decision.preservedLocalPaths['a'], '/m/a.m4a');
    });

    test('preserves an unchanged item so its file is not re-downloaded', () {
      final decision = planMediaCache(
        previous: const [
          CachedMediaRef(id: 'a', version: 'v1', localPath: '/m/a.m4a'),
        ],
        incoming: const [IncomingMediaRef(id: 'a', version: 'v1')],
      );
      expect(decision.filesToEvict, isEmpty);
      expect(decision.preservedLocalPaths['a'], '/m/a.m4a');
    });

    test('evicts a stale file and marks the item for re-download on version '
        'change', () {
      final decision = planMediaCache(
        previous: const [
          CachedMediaRef(id: 'a', version: 'v1', localPath: '/m/a.m4a'),
        ],
        incoming: const [IncomingMediaRef(id: 'a', version: 'v2')],
      );
      expect(decision.filesToEvict, ['/m/a.m4a']);
      // null preserved path => must re-download.
      expect(decision.preservedLocalPaths['a'], isNull);
    });

    test('a new item with no previous download needs a download and evicts '
        'nothing', () {
      final decision = planMediaCache(
        previous: const [],
        incoming: const [IncomingMediaRef(id: 'new', version: 'v1')],
      );
      expect(decision.filesToEvict, isEmpty);
      expect(decision.preservedLocalPaths['new'], isNull);
    });

    test('never evicts an item that was never downloaded (null local path)', () {
      final decision = planMediaCache(
        previous: const [CachedMediaRef(id: 'a', version: 'v1')],
        incoming: const [],
      );
      // Nothing to delete — there is no downloaded file, only the bundled
      // fallback (which is never a tracked file path).
      expect(decision.filesToEvict, isEmpty);
    });

    test('mixed rotation: keep one, evict a removed one, refresh a changed one',
        () {
      final decision = planMediaCache(
        previous: const [
          CachedMediaRef(id: 'keep', version: 'v1', localPath: '/m/keep.wav'),
          CachedMediaRef(id: 'gone', version: 'v1', localPath: '/m/gone.wav'),
          CachedMediaRef(id: 'bump', version: 'v1', localPath: '/m/bump.wav'),
        ],
        incoming: const [
          IncomingMediaRef(id: 'keep', version: 'v1'),
          IncomingMediaRef(id: 'bump', version: 'v2'),
          IncomingMediaRef(id: 'fresh', version: 'v1'),
        ],
      );
      expect(decision.filesToEvict, containsAll(['/m/gone.wav', '/m/bump.wav']));
      expect(decision.filesToEvict, hasLength(2));
      expect(decision.preservedLocalPaths['keep'], '/m/keep.wav');
      expect(decision.preservedLocalPaths['bump'], isNull);
      expect(decision.preservedLocalPaths['fresh'], isNull);
    });
  });

  group('CatalogStory JSON <-> map round-trips', () {
    test('fromCatalogJson parses server shape incl. excerpt list + mediaUrl',
        () {
      final story = CatalogStory.fromCatalogJson(const {
        'id': 'lighthouse',
        'title': 'The Lighthouse at Cape Horn',
        'series': 'Tales',
        'narrator': 'Capt. Lind',
        'teaser_subtitle': 'Narrated • 22 min',
        'excerpt': ['para one', 'para two'],
        'coordinates': '55S',
        'swell_note': '2.4m',
        'duration_label': '22 min',
        'mediaUrl': '/media/stories/lighthouse.m4a',
        'mediaVersion': '2026-01-01',
        'sort_order': 0,
        'active': true,
      });
      expect(story.excerpt, ['para one', 'para two']);
      expect(story.mediaUrl, '/media/stories/lighthouse.m4a');
      expect(story.active, isTrue);
    });

    test('toMap/fromMap preserves local bookkeeping and encodes excerpt', () {
      const story = CatalogStory(
        id: 'a',
        title: 'T',
        series: '',
        narrator: '',
        teaserSubtitle: '',
        excerpt: ['x', 'y'],
        coordinates: '',
        swellNote: '',
        durationLabel: '',
        mediaUrl: '/media/a.m4a',
        mediaVersion: 'v1',
        sortOrder: 2,
        active: true,
        localPath: '/m/a.m4a',
        downloadedAt: '2026-01-02',
      );
      final restored = CatalogStory.fromMap(story.toMap());
      expect(restored.excerpt, ['x', 'y']);
      expect(restored.localPath, '/m/a.m4a');
      expect(restored.downloadedAt, '2026-01-02');
      expect(restored.sortOrder, 2);
      expect(restored.active, isTrue);
    });
  });

  group('loreForDisplay — dailyLore only as tie-breaker', () {
    StoryData story(String id) => StoryData(
          title: id,
          series: '',
          narrator: '',
          coordinates: '',
          swellNote: '',
          vibeTags: const [],
          chapterProgress: '',
          chapterNumber: 1,
          chapterTitle: '',
          chapterTimestamp: '',
          excerpt: const [''],
          currentTime: '',
          remainingTime: '',
          progress: 0,
          teaserSubtitle: '',
          storyId: id,
          remoteMediaUrl: '/media/$id.m4a',
        );

    test('two or fewer active stories are shown directly, in order', () {
      final two = [story('a'), story('b')];
      final shown = loreForDisplay(two, DateTime(2026, 3, 5));
      expect(shown.map((s) => s.title), ['a', 'b']);

      final one = [story('a')];
      expect(loreForDisplay(one, DateTime(2026, 3, 5)).map((s) => s.title),
          ['a']);
    });

    test('more than two active stories collapse to a daily window of two', () {
      final four = [story('a'), story('b'), story('c'), story('d')];
      final shown = loreForDisplay(four, DateTime(2026, 3, 5));
      expect(shown, hasLength(2));
    });

    test('empty source yields nothing', () {
      expect(loreForDisplay(const [], DateTime(2026, 3, 5)), isEmpty);
    });
  });

  group('storyDataFromCatalog — server fields + client decoration', () {
    test('known id gets its authored vibe chips + chapter framing', () {
      const c = CatalogStory(
        id: 'lighthouse',
        title: 'The Lighthouse at Cape Horn',
        series: 'Tales',
        narrator: 'Capt. Lind',
        teaserSubtitle: 'Narrated • 22 min',
        excerpt: ['para'],
        coordinates: '55S',
        swellNote: '2.4m',
        durationLabel: '22 min',
        mediaUrl: '/media/stories/lighthouse.m4a',
        mediaVersion: 'v1',
        sortOrder: 0,
        active: true,
      );
      final data = storyDataFromCatalog(c);
      expect(data.title, 'The Lighthouse at Cape Horn');
      expect(data.chapterTitle, "The Keeper's Lantern");
      expect(data.vibeTags, isNotEmpty);
      expect(data.hasRemoteMedia, isTrue);
      expect(data.remoteMediaUrl, '/media/stories/lighthouse.m4a');
    });

    test('unknown id still renders via the default decoration', () {
      const c = CatalogStory(
        id: 'brand_new_tale',
        title: 'A New Tale',
        series: 'Horizon Tales',
        narrator: 'Someone',
        teaserSubtitle: 'New • 10 min',
        excerpt: [],
        coordinates: '',
        swellNote: '',
        durationLabel: '10 min',
        mediaUrl: '/media/stories/new.m4a',
        mediaVersion: 'v1',
        sortOrder: 9,
        active: true,
      );
      final data = storyDataFromCatalog(c);
      expect(data.title, 'A New Tale');
      expect(data.vibeTags, isNotEmpty); // default decoration applied
      expect(data.excerpt, isNotEmpty); // placeholder excerpt supplied
      expect(data.hasRemoteMedia, isTrue);
    });
  });
}
