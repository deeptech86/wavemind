import 'dart:math';

/// The four foghorn "signal" pitches the pattern is built from — framed as
/// compass-relative bearings (a real fog signal's whole purpose at sea is
/// telling you *where* a sound is coming from), distinguished in practice by
/// pitch-shifting the single bundled foghorn sample (see FogSignalEchoScreen).
enum FogSignal { bow, starboard, stern, port }

/// Pure, audio-/UI-independent model for the "Fog Signal Echo" pattern-
/// memory game: the game calls out a growing sequence of foghorn signals;
/// the sailor echoes it back in the same order. One wrong tap doesn't end
/// the session — it just replays the current round for another try, kept
/// deliberately non-punishing to match the app's calm tone. Reaching
/// [targetRounds] completes the session.
class FogSignalEcho {
  FogSignalEcho({this.targetRounds = 8, Random? random})
    : _random = random ?? Random();

  final Random _random;

  /// Sequence length (== round number) needed to complete the session.
  final int targetRounds;

  final List<FogSignal> _sequence = [];
  int _playerIndex = 0;

  /// The pattern so far, oldest signal first.
  List<FogSignal> get sequence => List.unmodifiable(_sequence);

  /// Current round == how many signals are in the sequence so far.
  int get round => _sequence.length;

  bool get isComplete => round >= targetRounds;

  /// Starts a new round: appends one random signal (growing the sequence by
  /// one) and resets the sailor's echo position to the start. Call once at
  /// the beginning of a session and again after each round is echoed back
  /// correctly.
  FogSignal nextRound() {
    final next = FogSignal.values[_random.nextInt(FogSignal.values.length)];
    _sequence.add(next);
    _playerIndex = 0;
    return next;
  }

  /// Replays the current round from the start without growing the
  /// sequence — call after a mistake so the sailor gets another try at the
  /// same pattern instead of losing progress.
  void retryRound() => _playerIndex = 0;

  /// Feeds the sailor's next tap. Returns whether it matched the expected
  /// next signal in the sequence; advances the echo position only on a
  /// match. Does not itself decide what happens on a mismatch — that's the
  /// caller's call (typically [retryRound]).
  bool echo(FogSignal signal) {
    final expected = _sequence[_playerIndex];
    final matched = expected == signal;
    if (matched) _playerIndex++;
    return matched;
  }

  /// Whether the sailor has echoed the full sequence for the current round.
  bool get roundComplete => _playerIndex >= _sequence.length;

  /// Clears everything for a fresh session.
  void reset() {
    _sequence.clear();
    _playerIndex = 0;
  }
}
