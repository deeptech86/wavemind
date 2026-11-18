import 'dart:math';

/// What happened as a result of a single tile tap in [CalmYourWaves].
enum CalmTapResult {
  /// The tap didn't do anything — the tile is already matched, already the
  /// sole face-up pick, or a mismatched pair is still waiting to be cleared.
  ignored,

  /// First tile of a pair picked; waiting on a second tap.
  picked,

  /// The second tile matched the first — both are now matched and out of
  /// play.
  matched,

  /// The second tile didn't match the first. Both stay face up until
  /// [CalmYourWaves.clearMismatch] is called.
  mismatch,
}

/// Pure, UI-independent model for the "Calm Your Waves" memory-match game.
///
/// All tiles flash face up at the start of a level, then flip back down —
/// the player must remember what sat where and tap pairs of matching tiles
/// until the whole board is cleared. Levels grow from 2 pairs (4 tiles) up to
/// the full 32 pairs (64 tiles) in [pairCountsByLevel].
///
/// The "flash everything, then hide" preview and the brief peek on a wrong
/// guess are timing concerns owned by the UI (via a delayed callback); this
/// engine only tracks the resulting state so it stays unit-testable without a
/// widget harness or a real clock.
class CalmYourWaves {
  CalmYourWaves._({
    required this.levelIndex,
    required List<int> designs,
    required Random random,
  })  : _designs = designs,
        _random = random;

  /// Ascending pair counts per level, 2 pairs through the full 32-pair board,
  /// capped at 10 levels.
  static const List<int> pairCountsByLevel = [
    2, 3, 4, 6, 8, 12, 16, 20, 26, 32,
  ];

  static final int maxLevelIndex = pairCountsByLevel.length - 1;

  /// Builds the board for [levelIndex] (0-based, clamped to the known
  /// levels), with designs paired up and shuffled. [random] is injectable for
  /// tests; a fresh board always carries the same [Random] forward so a
  /// session's shuffles aren't all seeded identically.
  factory CalmYourWaves.level(int levelIndex, {Random? random}) {
    final rng = random ?? Random();
    final clamped = levelIndex.clamp(0, maxLevelIndex);
    final pairs = pairCountsByLevel[clamped];
    final designs = <int>[
      for (var d = 0; d < pairs; d++) ...[d, d],
    ]..shuffle(rng);
    return CalmYourWaves._(levelIndex: clamped, designs: designs, random: rng);
  }

  final int levelIndex;
  final List<int> _designs;
  final Random _random;

  final Set<int> _matched = {};
  int? _firstPick;
  int? _secondPick; // only set once a mismatch is pending

  int get pairCount => pairCountsByLevel[levelIndex];
  int get tileCount => _designs.length;

  /// The design id behind each tile, stable for the life of this level.
  List<int> get designs => List.unmodifiable(_designs);

  bool isMatched(int index) => _matched.contains(index);

  /// Whether [index] is currently showing its design — matched, the lone
  /// pending pick, or part of a not-yet-cleared mismatched pair.
  bool isFaceUp(int index) =>
      isMatched(index) || index == _firstPick || index == _secondPick;

  /// The two tiles showing a wrong guess, waiting on [clearMismatch]. Empty
  /// while no mismatch is pending.
  List<int> get pendingMismatch =>
      _secondPick == null ? const [] : [_firstPick!, _secondPick!];

  bool get hasPendingMismatch => _secondPick != null;

  int get matchedPairs => _matched.length ~/ 2;
  bool get isComplete => _matched.length == _designs.length;
  bool get hasNextLevel => levelIndex < maxLevelIndex;

  /// Fraction of pairs matched so far, in `[0, 1]`.
  double get fraction => pairCount == 0 ? 0 : matchedPairs / pairCount;

  /// Taps tile [index]. See [CalmTapResult] for what can happen.
  CalmTapResult tap(int index) {
    if (hasPendingMismatch) return CalmTapResult.ignored;
    if (isMatched(index)) return CalmTapResult.ignored;
    if (index == _firstPick) return CalmTapResult.ignored;

    if (_firstPick == null) {
      _firstPick = index;
      return CalmTapResult.picked;
    }

    if (_designs[_firstPick!] == _designs[index]) {
      _matched
        ..add(_firstPick!)
        ..add(index);
      _firstPick = null;
      return CalmTapResult.matched;
    }

    _secondPick = index;
    return CalmTapResult.mismatch;
  }

  /// Flips a mismatched pair back face-down. Call once the UI's brief peek
  /// delay has elapsed; taps are ignored until this runs.
  void clearMismatch() {
    _firstPick = null;
    _secondPick = null;
  }

  /// A fresh board for the next level up, carrying the same [Random] forward.
  CalmYourWaves nextLevel() {
    assert(hasNextLevel, 'already at the final level');
    return CalmYourWaves.level(levelIndex + 1, random: _random);
  }

  /// A freshly shuffled board for the *current* level (progress reset).
  CalmYourWaves retryLevel() => CalmYourWaves.level(levelIndex, random: _random);

  /// A freshly shuffled board back at the first level.
  CalmYourWaves restart() => CalmYourWaves.level(0, random: _random);
}
