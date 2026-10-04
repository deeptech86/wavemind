import 'dart:math';
import 'dart:ui' show Offset;

/// The outcome of threading the rope end onto a target in [KnotPuzzle].
enum KnotStepResult {
  /// The tapped/dropped target was the next one in the tying sequence.
  correct,

  /// The target was not the next one in the sequence (a foul move).
  wrong,

  /// The target was correct *and* it was the final step — the knot is secured.
  completed,
}

/// A single loop / anchor-point the rope end must be threaded through.
class KnotTarget {
  const KnotTarget({required this.id, required this.position});

  /// Stable identifier for the target (independent of tying order).
  final int id;

  /// Normalized position within the tying arena, each axis in `[0, 1]`.
  final Offset position;
}

/// Pure, UI-independent model for the "Knot Master 3D" bowline-tying puzzle.
///
/// A round presents a fixed set of [targets] (loops / anchor points) arranged in
/// the arena, plus an [order]: the sequence of target ids the rope end must be
/// threaded through to tie the knot. The player advances by registering each
/// target; threading them in the right order ties the knot, a wrong one is a
/// foul move that leaves progress untouched so the round stays recoverable.
///
/// The order is randomized per round (see [KnotPuzzle.shuffled]) so the game is
/// replayable rather than a single fixed solution. Kept free of Flutter imports
/// so the sequence logic is unit-testable without a widget/haptic harness.
class KnotPuzzle {
  KnotPuzzle({required this.targets, required this.order}) : _progress = 0 {
    assert(targets.isNotEmpty, 'A knot needs at least one target');
    assert(
      order.length == targets.length,
      'order must thread every target exactly once',
    );
    assert(
      order.toSet().length == order.length,
      'order must not repeat a target',
    );
    assert(
      order.every((id) => targets.any((t) => t.id == id)),
      'order ids must all reference a known target',
    );
  }

  /// Builds a round with the canonical bowline layout and a randomized order.
  ///
  /// The classic mnemonic has five beats — "the rabbit comes out of the hole,
  /// round the tree, and back down the hole" — so five targets read naturally.
  /// [random] is injectable for deterministic tests.
  factory KnotPuzzle.shuffled({Random? random}) {
    final rng = random ?? Random();
    const targets = _bowlineTargets;
    final order = targets.map((t) => t.id).toList()..shuffle(rng);
    return KnotPuzzle(targets: List.of(targets), order: order);
  }

  /// Canonical loop positions for the bowline arena (normalized coordinates).
  static const List<KnotTarget> _bowlineTargets = [
    KnotTarget(id: 0, position: Offset(0.22, 0.30)),
    KnotTarget(id: 1, position: Offset(0.72, 0.24)),
    KnotTarget(id: 2, position: Offset(0.80, 0.68)),
    KnotTarget(id: 3, position: Offset(0.44, 0.78)),
    KnotTarget(id: 4, position: Offset(0.50, 0.48)),
  ];

  /// The loops / anchor points, in stable id order (not tying order).
  final List<KnotTarget> targets;

  /// The correct sequence of target ids to tie the knot.
  final List<int> order;

  int _progress;

  /// How many steps have been threaded correctly so far.
  int get progress => _progress;

  /// Total steps required to tie the knot.
  int get totalSteps => order.length;

  /// Whether the knot is fully tied.
  bool get isComplete => _progress >= order.length;

  /// Fraction tied so far, in `[0, 1]`.
  double get fraction => order.isEmpty ? 1 : _progress / order.length;

  /// The id of the next target the rope must be threaded through, or `null`
  /// once the knot is complete.
  int? get nextTargetId => isComplete ? null : order[_progress];

  /// Whether [id] is the next target to thread (useful for UI hinting).
  bool isNext(int id) => !isComplete && order[_progress] == id;

  /// Whether [id] has already been threaded in this round.
  bool isThreaded(int id) {
    final idx = order.indexOf(id);
    return idx >= 0 && idx < _progress;
  }

  /// Registers the rope end arriving at target [id].
  ///
  /// Returns [KnotStepResult.correct] when it advances the knot (and more steps
  /// remain), [KnotStepResult.completed] when it was the final step, or
  /// [KnotStepResult.wrong] for a foul move (progress unchanged).
  KnotStepResult registerTarget(int id) {
    if (isComplete) return KnotStepResult.completed;
    if (order[_progress] != id) return KnotStepResult.wrong;
    _progress++;
    return isComplete ? KnotStepResult.completed : KnotStepResult.correct;
  }

  /// Resets progress to the start of the round (same layout and order).
  void reset() => _progress = 0;
}
