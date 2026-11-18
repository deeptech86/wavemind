import 'dart:math';

/// A single irregular, flattened river stone in [StoneCairn]. The actual
/// jagged outline is derived from [shapeSeed] by the UI (a jittered oval) —
/// this model only tracks size, tone, and the small cosmetic lean it picked
/// up when it was last placed.
class Stone {
  Stone({
    required this.id,
    required this.shapeSeed,
    required this.radius,
    required this.toneIndex,
  });

  final int id;

  /// Seeds the UI's irregular polygon so the same stone always renders the
  /// same jagged shape.
  final int shapeSeed;

  /// Relative size, roughly in `[0.35, 1.0]` — bigger stones belong lower in
  /// the tower: stack a meaningfully bigger stone on a smaller one and the
  /// tower topples (see [StoneCairn.dropOnTop]).
  final double radius;

  /// Index into the UI's stone-tone palette.
  final int toneIndex;

  /// How far this stone's center sits left/right of the tower's central
  /// axis, roughly in `[-1, 1]` (a fraction of its own half-width). Drives
  /// both the visual lean and, past a threshold, whether the tower topples.
  double offsetFraction = 0;

  /// Small rotation (radians) picked up from the lean, plus a touch of
  /// randomness so no two placements look identical.
  double tilt = 0;
}

/// What happened when a stone was dropped onto the tower.
enum DropOutcome {
  /// The stone joined the tower and everything is still standing.
  stable,

  /// The stone joined the tower, but the resulting stack is unbalanced —
  /// either it (or something below it) leans too far, or a stone is
  /// meaningfully bigger than the one it's resting on. The tower is about to
  /// topple; the caller should animate the fall and then call [StoneCairn.collapse].
  unstable,
}

/// Pure, UI-independent model for the "Stone Cairn Balance" sandbox — a
/// single vertical tower of stones, side-view, like a real balanced-rock
/// cairn (not a scattered top-down pile).
///
/// A fresh round scatters [stones] of irregular, varied size in a tray. The
/// player drags any stone onto the tower and it joins the top of the stack,
/// leaning a little toward whichever side it was dropped on. Dragging a
/// stone that is *already* in the tower picks it back up and restacks it on
/// top again.
///
/// Balance is real, if simplified: stack a stone meaningfully bigger than
/// the one beneath it, or drop one too far off-center, and the whole tower
/// topples (see [dropOnTop] / [DropOutcome.unstable]) — the player has to
/// start the tower over. There is still no *single* correct arrangement
/// (stones of similar size can go in either order, and a little lean is
/// fine), just a real physical constraint rather than none at all.
/// [isComplete] tracks whether every stone has joined the (currently
/// standing) tower at least once.
class StoneCairn {
  StoneCairn._(this.stones, List<int> stackOrder, Random random)
    : _stackOrder = stackOrder,
      _random = random;

  /// Stone-tone palette size the UI cycles through via [Stone.toneIndex].
  static const int toneCount = 5;

  /// How much bigger (in [Stone.radius] units) a stone may be than the one
  /// it rests on before the tower is judged unstable.
  static const double sizeTolerance = 0.12;

  /// Lean threshold for a stone resting on another stone — past this, the
  /// tower topples.
  static const double stackLeanLimit = 0.62;

  /// Lean threshold for the base stone, resting directly on the ground —
  /// more forgiving than stone-on-stone, same as in life.
  static const double groundLeanLimit = 0.85;

  /// Builds a fresh round of [stoneCount] stones, biggest first (echoing
  /// real cairn-building — base stones are naturally larger), with jittered
  /// sizes/shapes/tones so no two rounds look alike. [random] is injectable
  /// for tests.
  factory StoneCairn.generate({int stoneCount = 7, Random? random}) {
    final rng = random ?? Random();
    final stones = <Stone>[];
    for (var i = 0; i < stoneCount; i++) {
      final base = 1.0 - (i / stoneCount) * 0.65; // descending base size
      final radius = (base + (rng.nextDouble() - 0.5) * 0.12).clamp(0.35, 1.0);
      stones.add(
        Stone(
          id: i,
          shapeSeed: rng.nextInt(1 << 31),
          radius: radius,
          toneIndex: rng.nextInt(toneCount),
        ),
      );
    }
    return StoneCairn._(stones, <int>[], rng);
  }

  /// All stones in this round, in fixed generation (biggest-first) order —
  /// independent of stacking order, so the tray has a stable sort.
  final List<Stone> stones;

  /// Stack order, bottom to top. Only ids — [Stone] instances live in
  /// [stones], looked up via [byId].
  final List<int> _stackOrder;
  final Random _random;

  /// The tower, bottom to top.
  List<int> get stackOrder => List.unmodifiable(_stackOrder);

  int get stoneCount => stones.length;
  int get placedCount => _stackOrder.length;
  bool get isComplete => stones.isNotEmpty && placedCount == stoneCount;
  double get fraction => stones.isEmpty ? 0 : placedCount / stoneCount;

  bool isPlaced(int id) => _stackOrder.contains(id);

  Stone byId(int id) => stones.firstWhere((s) => s.id == id);

  /// Places stone [id] on top of the tower — removing it from its old spot
  /// in the stack first, if it was already placed, so it always ends up as
  /// the topmost stone. [offsetFraction] is the left/right lean picked up
  /// from where it was dropped, roughly in `[-1, 1]`; it's clamped and gets
  /// a touch of extra random jitter so the tower never looks mechanically
  /// perfect.
  ///
  /// Returns [DropOutcome.unstable] if the resulting stack is unbalanced.
  /// The stack is left exactly as placed either way — [collapse] is a
  /// separate step so the caller can animate the fall first.
  DropOutcome dropOnTop(int id, {double offsetFraction = 0}) {
    _stackOrder.remove(id);
    _stackOrder.add(id);
    final clamped = offsetFraction.clamp(-1.0, 1.0);
    final stone = byId(id);
    stone.offsetFraction = clamped;
    stone.tilt = clamped * 0.22 + (_random.nextDouble() - 0.5) * 0.08;
    return _isStable() ? DropOutcome.stable : DropOutcome.unstable;
  }

  bool _isStable() {
    for (var i = 0; i < _stackOrder.length; i++) {
      final stone = byId(_stackOrder[i]);
      final leanLimit = i == 0 ? groundLeanLimit : stackLeanLimit;
      if (stone.offsetFraction.abs() > leanLimit) return false;
      if (i > 0) {
        final below = byId(_stackOrder[i - 1]);
        if (stone.radius > below.radius + sizeTolerance) return false;
      }
    }
    return true;
  }

  /// Clears the tower after a [DropOutcome.unstable] drop — every stone
  /// returns to the tray, unplaced.
  void collapse() {
    _stackOrder.clear();
  }

  /// A fresh round, discarding the current tower entirely.
  StoneCairn newRound({int? stoneCount, Random? random}) => StoneCairn.generate(
    stoneCount: stoneCount ?? this.stoneCount,
    random: random,
  );
}
