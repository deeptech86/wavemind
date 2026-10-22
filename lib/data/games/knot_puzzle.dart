import 'dart:math';
import 'dart:ui' show Offset;

/// The outcome of a single connection attempt in [KnotPuzzle].
enum KnotStepResult {
  /// The rope reached an open loop without crossing any line already run —
  /// the path extended by one clean segment.
  connected,

  /// The closing pass back to the anchor landed clean — the loop is secured.
  closed,

  /// The attempted segment crossed a line already run — the knot is fouled.
  overlap,

  /// The move was not allowed right now (e.g. the loop is already linked, or
  /// the round is already over). State is left untouched.
  rejected,
}

/// Where a round currently stands.
enum KnotPhase { inProgress, success, failed }

/// A single loop / anchor-point the rope is run through in [KnotPuzzle].
class KnotTarget {
  const KnotTarget({required this.id, required this.position});

  /// Stable identifier for the loop.
  final int id;

  /// Normalized position within the tying arena, each axis in `[0, 1]`.
  final Offset position;
}

/// A directed segment of the rope path, identified by its two loop ids.
class KnotSegment {
  const KnotSegment(this.fromId, this.toId);

  final int fromId;
  final int toId;

  @override
  bool operator ==(Object other) =>
      other is KnotSegment && other.fromId == fromId && other.toId == toId;

  @override
  int get hashCode => Object.hash(fromId, toId);
}

/// Records the collision that fouled a round: the segment the player was
/// drawing and the earlier segment it crossed. The UI uses this to flash the
/// two offending lines red before showing the failure state.
class KnotCrossing {
  const KnotCrossing({required this.newSegment, required this.hitSegment});

  final KnotSegment newSegment;
  final KnotSegment hitSegment;
}

/// Pure, UI-independent model for the "Knot Master 3D" loop-tying puzzle.
///
/// A round scatters [targets] (loops) at random positions in the arena and
/// nominates one as the anchor ([startId]). The player runs the rope from the
/// anchor through every other loop — **in any order they like** — and finally
/// back to the anchor, forming a closed loop. The one rule: a newly-run segment
/// may never cross a segment already run. Cross a line and the knot fouls
/// ([KnotPhase.failed]); close a clean loop through every point and the knot is
/// secured ([KnotPhase.success]).
///
/// Every random layout is guaranteed solvable: positions are generated so the
/// points sit in general position (no three near-collinear), and for any such
/// point set the "star-shaped polygon" built from an extreme pivot — pivot,
/// then the rest sorted by polar angle around it, then back to pivot — is
/// provably non-self-crossing. We nominate that pivot as the anchor, so at
/// least one clean order always exists. Validity of the *player's* path is
/// never compared against that one solution, though — it is checked live via
/// real segment/segment intersection tests, so any non-crossing order wins.
///
/// Kept free of Flutter imports so the geometry stays unit-testable without a
/// widget/haptic harness.
class KnotPuzzle {
  KnotPuzzle._({required this.targets, required this.startId})
      : _path = <int>[startId] {
    assert(targets.length >= 3, 'A closed loop needs at least three loops');
    assert(
      targets.map((t) => t.id).toSet().length == targets.length,
      'loop ids must be unique',
    );
    assert(targets.any((t) => t.id == startId), 'startId must be a known loop');
  }

  /// Builds a round with [loopCount] randomly-placed loops, guaranteed to have
  /// at least one non-crossing solution. [random] is injectable for tests.
  factory KnotPuzzle.random({Random? random, int loopCount = 5}) {
    final rng = random ?? Random();
    final targets = _generateTargets(rng, loopCount);
    return KnotPuzzle._(targets: targets, startId: _pivotId(targets));
  }

  /// Builds a round from explicit loops (for tests / deterministic layouts).
  /// [startId] defaults to the pivot the solver would nominate.
  factory KnotPuzzle.fromTargets(List<KnotTarget> targets, {int? startId}) {
    final list = List.of(targets);
    return KnotPuzzle._(
      targets: list,
      startId: startId ?? _pivotId(list),
    );
  }

  /// The loops, in stable id order (independent of the player's path).
  final List<KnotTarget> targets;

  /// The anchor loop the path starts from and must close back to.
  final int startId;

  final List<int> _path;
  KnotPhase _phase = KnotPhase.inProgress;
  KnotCrossing? _crossing;

  /// The ordered loop ids the rope currently runs through. The first entry is
  /// always [startId]; once the knot is secured the anchor is repeated as the
  /// final entry (the closing pass).
  List<int> get path => List.unmodifiable(_path);

  KnotPhase get phase => _phase;
  bool get isInProgress => _phase == KnotPhase.inProgress;
  bool get isSuccess => _phase == KnotPhase.success;
  bool get isFailed => _phase == KnotPhase.failed;

  /// Details of the crossing that fouled the round, or `null` if none.
  KnotCrossing? get crossing => _crossing;

  /// The loop the rope's working end currently sits on.
  int get currentEndId => _path.last;

  /// Total loops in the round.
  int get totalLoops => targets.length;

  /// Segments needed to complete the closed loop (one per loop).
  int get totalSegments => targets.length;

  /// Segments run clean so far (caps at [totalSegments] on success).
  int get segmentsDrawn => min(_path.length - 1, totalSegments);

  /// Whether every loop has been linked and only the closing pass remains.
  bool get allLinked =>
      isInProgress && _path.length == targets.length;

  /// Whether the player may now close the loop back onto the anchor.
  bool get canClose => allLinked;

  /// Fraction of the closed loop run so far, in `[0, 1]`.
  double get fraction =>
      totalSegments == 0 ? 0 : segmentsDrawn / totalSegments;

  /// Whether [id] is already part of the rope path.
  bool isLinked(int id) => _path.contains(id);

  /// Whether [id] is a loop the rope may be run to *next*. While loops remain,
  /// every un-linked loop is fair game (free order). Once all are linked, only
  /// the anchor is a candidate — to close the loop.
  bool isCandidate(int id) {
    if (!isInProgress) return false;
    if (id == currentEndId) return false;
    if (allLinked) return id == startId;
    return !isLinked(id);
  }

  Offset _pos(int id) => targets.firstWhere((t) => t.id == id).position;

  /// Runs the rope's working end onto loop [id].
  ///
  /// Returns [KnotStepResult.rejected] if the move isn't currently legal,
  /// [KnotStepResult.overlap] (and transitions to [KnotPhase.failed]) if the
  /// new segment crosses a line already run, [KnotStepResult.closed] (and
  /// transitions to [KnotPhase.success]) if it was a clean closing pass, and
  /// [KnotStepResult.connected] for any other clean segment.
  KnotStepResult connect(int id) {
    if (!isInProgress) return KnotStepResult.rejected;

    final closing = allLinked && id == startId;
    if (!closing) {
      if (allLinked) return KnotStepResult.rejected; // only the close remains
      if (isLinked(id)) return KnotStepResult.rejected;
      if (id == currentEndId) return KnotStepResult.rejected;
    }

    final fromId = currentEndId;
    final p = _pos(fromId);
    final q = _pos(id);

    // Test the new segment against every segment already run, skipping any that
    // share an endpoint with it. Adjacent segments meet at a shared loop by
    // design — that touch is not a crossing — and the closing pass is adjacent
    // to *both* the first and last run segments, which this same rule excludes.
    for (var i = 0; i + 1 < _path.length; i++) {
      final aId = _path[i];
      final bId = _path[i + 1];
      if (aId == fromId || bId == fromId || aId == id || bId == id) {
        continue; // shares an endpoint -> adjacent, not a crossing
      }
      if (segmentsCross(p, q, _pos(aId), _pos(bId))) {
        _crossing = KnotCrossing(
          newSegment: KnotSegment(fromId, id),
          hitSegment: KnotSegment(aId, bId),
        );
        _phase = KnotPhase.failed;
        return KnotStepResult.overlap;
      }
    }

    _path.add(id);
    if (closing) {
      _phase = KnotPhase.success;
      return KnotStepResult.closed;
    }
    return KnotStepResult.connected;
  }

  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

  /// True iff open segments `p1p2` and `p3p4` *properly* cross — their interiors
  /// intersect at a single point. Uses the standard orientation (cross-product)
  /// test: the two cases hold only when each segment straddles the line of the
  /// other, i.e. the endpoints fall on strictly opposite sides. Shared or
  /// touching endpoints give a zero orientation and are deliberately reported as
  /// *not* crossing, which is why adjacent path segments (and T-junctions, ruled
  /// out anyway by the general-position guarantee) never false-positive.
  static bool segmentsCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    double orient(Offset a, Offset b, Offset c) =>
        (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    bool oppositeSides(double a, double b) =>
        (a > 0 && b < 0) || (a < 0 && b > 0);

    final d1 = orient(p3, p4, p1);
    final d2 = orient(p3, p4, p2);
    final d3 = orient(p1, p2, p3);
    final d4 = orient(p1, p2, p4);
    return oppositeSides(d1, d2) && oppositeSides(d3, d4);
  }

  /// The pivot loop id — lowest y, tie-broken by lowest x. It lies on the
  /// convex hull, so it anchors a star-shaped (simple) polygon.
  static int _pivotId(List<KnotTarget> targets) {
    var pivot = targets.first;
    for (final t in targets.skip(1)) {
      final p = t.position;
      final best = pivot.position;
      if (p.dy < best.dy || (p.dy == best.dy && p.dx < best.dx)) {
        pivot = t;
      }
    }
    return pivot.id;
  }

  /// A provably non-crossing closed tour of [targets]: the pivot, then the
  /// remaining loops sorted by polar angle around it (ties broken by distance),
  /// which implicitly closes back to the pivot. Returned as the loop-id order
  /// (pivot not repeated at the end). Used to *generate* solvable layouts and
  /// by tests; the engine never uses it to validate the player's own path.
  static List<int> solutionCycle(List<KnotTarget> targets) {
    final pivotId = _pivotId(targets);
    final pivot = targets.firstWhere((t) => t.id == pivotId).position;
    final rest = targets.where((t) => t.id != pivotId).toList()
      ..sort((a, b) {
        final angA = atan2(a.position.dy - pivot.dy, a.position.dx - pivot.dx);
        final angB = atan2(b.position.dy - pivot.dy, b.position.dx - pivot.dx);
        if (angA != angB) return angA.compareTo(angB);
        return (a.position - pivot)
            .distanceSquared
            .compareTo((b.position - pivot).distanceSquared);
      });
    return [pivotId, ...rest.map((t) => t.id)];
  }

  // ---------------------------------------------------------------------------
  // Layout generation
  // ---------------------------------------------------------------------------

  static const double _margin = 0.14; // keep loops off the arena edge
  static const double _minSpacing = 0.22; // min gap between loops (normalized)
  static const double _minArea = 0.02; // collinearity guard (twice-triangle)

  /// Generates [count] loops in general position: well spaced and with no three
  /// near-collinear, so the star-polygon solvability guarantee holds cleanly and
  /// segment-crossing tests stay numerically unambiguous. Retries until a valid
  /// set is found (always fast for a handful of points in a unit square).
  static List<KnotTarget> _generateTargets(Random rng, int count) {
    while (true) {
      final pts = _scatter(rng, count);
      if (pts == null) continue; // couldn't place that many with the spacing
      if (!_inGeneralPosition(pts)) continue;
      return [
        for (var i = 0; i < pts.length; i++)
          KnotTarget(id: i, position: pts[i]),
      ];
    }
  }

  /// Poisson-ish rejection sampling: drop points one by one, keeping only those
  /// at least [_minSpacing] from the rest. Returns `null` if it can't fit them.
  static List<Offset>? _scatter(Random rng, int count) {
    final pts = <Offset>[];
    const span = 1 - 2 * _margin;
    for (var attempt = 0; attempt < 3000 && pts.length < count; attempt++) {
      final p = Offset(
        _margin + rng.nextDouble() * span,
        _margin + rng.nextDouble() * span,
      );
      if (pts.every((q) => (q - p).distance >= _minSpacing)) {
        pts.add(p);
      }
    }
    return pts.length == count ? pts : null;
  }

  /// True iff no three points are near-collinear (every triangle's twice-area
  /// exceeds [_minArea]).
  static bool _inGeneralPosition(List<Offset> pts) {
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        for (var k = j + 1; k < pts.length; k++) {
          final a = pts[i];
          final b = pts[j];
          final c = pts[k];
          final twiceArea =
              ((b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx))
                  .abs();
          if (twiceArea < _minArea) return false;
        }
      }
    }
    return true;
  }
}
