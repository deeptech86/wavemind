/// Standard seven-segment layout, shared by the engine and the UI painter:
/// 0 top, 1 topLeft, 2 topRight, 3 middle, 4 bottomLeft, 5 bottomRight,
/// 6 bottom.
const Map<int, Set<int>> digitSegments = {
  0: {0, 1, 2, 4, 5, 6},
  1: {2, 5},
  2: {0, 2, 3, 4, 6},
  3: {0, 2, 3, 5, 6},
  4: {1, 2, 3, 5},
  5: {0, 1, 3, 5, 6},
  6: {0, 1, 3, 4, 5, 6},
  7: {0, 2, 5},
  8: {0, 1, 2, 3, 4, 5, 6},
  9: {0, 1, 2, 3, 5, 6},
};

int? _digitForSegments(Set<int> segments) {
  for (final entry in digitSegments.entries) {
    if (entry.value.length == segments.length && entry.value.containsAll(segments)) {
      return entry.key;
    }
  }
  return null;
}

/// A single token in a [MatchstickPuzzle]: either a digit (built from
/// segments the player can relocate sticks between) or a fixed operator
/// (`+`, `-`, `=`) that never changes.
class MatchToken {
  const MatchToken.digit(this.value) : operator = null;
  const MatchToken.operator(this.operator) : value = null;

  final int? value;
  final String? operator;

  bool get isDigit => value != null;
}

/// What kind of challenge a [MatchstickPuzzle] poses.
enum MatchPuzzleType {
  /// The equation is false; move one stick to make it true.
  fixEquation,

  /// Move one stick to make the biggest number reachable from this exact
  /// starting layout.
  biggestNumber,

  /// A single digit; move one stick (within it) to turn it into a
  /// *different* valid digit.
  differentDigit,
}

/// A single-matchstick relocation: from token [fromToken]'s segment
/// [fromSegment] to token [toToken]'s segment [toSegment] (same token for a
/// same-digit reshape, different tokens for a cross-digit donation).
class MatchMove {
  const MatchMove(this.fromToken, this.fromSegment, this.toToken, this.toSegment);

  final int fromToken;
  final int fromSegment;
  final int toToken;
  final int toSegment;

  @override
  bool operator ==(Object other) =>
      other is MatchMove &&
      other.fromToken == fromToken &&
      other.fromSegment == fromSegment &&
      other.toToken == toToken &&
      other.toSegment == toSegment;

  @override
  int get hashCode => Object.hash(fromToken, fromSegment, toToken, toSegment);
}

enum MoveResult {
  /// The relocation isn't legal right now — nothing lit at the source, the
  /// destination is already occupied, a move has already been used this
  /// round, or the resulting shape(s) aren't real digits.
  invalid,

  /// The stick relocated.
  moved,
}

/// Pure, UI-independent model for the "Matchstick Puzzle" game.
///
/// A row of digits (and, for [MatchPuzzleType.fixEquation], fixed `+`/`-`/`=`
/// signs) is built from seven-segment digits. The player relocates exactly
/// one matchstick — either reshaping a single digit in place (e.g. 2 -> 3)
/// or donating a stick from one digit to another (e.g. an 8 sheds a stick to
/// become a 6, and a 1 elsewhere gains it to become a 7) — and every
/// resulting digit must still be a real, recognizable digit; a move that
/// would leave a broken shape is rejected outright. Only one move is allowed
/// per round (see [hasMoved]); [reset] starts the same puzzle over.
///
/// [isSolved] means a move has been made *and* it satisfies the puzzle's
/// [MatchPuzzleType] — a true equation, a strictly bigger number than
/// anything else reachable in one move, or a different valid digit.
class MatchstickPuzzle {
  MatchstickPuzzle._({
    required this.type,
    required this.prompt,
    required List<MatchToken> template,
  }) : _template = template,
       _segments = [
         for (final t in template)
           t.isDigit ? Set<int>.of(digitSegments[t.value]!) : null,
       ],
       _initialSegments = [
         for (final t in template)
           t.isDigit ? Set<int>.of(digitSegments[t.value]!) : null,
       ] {
    _maxReachableValue =
        type == MatchPuzzleType.biggestNumber ? _computeMaxReachable() : null;
  }

  /// Parses a notation string like `"5+7=2"` (digits plus `+`/`-`/`=`; any
  /// other characters are ignored) into a fresh puzzle.
  factory MatchstickPuzzle.fromNotation(
    String notation, {
    required MatchPuzzleType type,
    required String prompt,
  }) {
    final tokens = <MatchToken>[];
    for (final ch in notation.split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        tokens.add(MatchToken.digit(digit));
      } else if (ch == '+' || ch == '-' || ch == '=') {
        tokens.add(MatchToken.operator(ch));
      }
    }
    return MatchstickPuzzle._(type: type, prompt: prompt, template: tokens);
  }

  final MatchPuzzleType type;
  final String prompt;
  final List<MatchToken> _template;
  final List<Set<int>?> _segments;
  final List<Set<int>?> _initialSegments;
  late final int? _maxReachableValue;

  int get tokenCount => _template.length;
  bool isDigitToken(int i) => _template[i].isDigit;
  String operatorAt(int i) => _template[i].operator!;

  /// The segments currently lit for digit token [i].
  Set<int> segmentsAt(int i) => Set.unmodifiable(_segments[i] ?? const {});

  /// The current value of digit token [i], or null if its shape doesn't
  /// match any real digit (shouldn't happen via [move], which rejects
  /// broken shapes, but is used defensively).
  int? digitValueAt(int i) {
    final segs = _segments[i];
    return segs == null ? null : _digitForSegments(segs);
  }

  bool get hasMoved {
    for (var i = 0; i < _segments.length; i++) {
      final a = _segments[i];
      final b = _initialSegments[i];
      if (a == null || b == null) continue;
      if (a.length != b.length || !a.containsAll(b)) return true;
    }
    return false;
  }

  /// Relocates one stick from token [fromToken]'s segment [fromSegment] to
  /// token [toToken]'s segment [toSegment]. Only the first move each round
  /// is allowed; call [reset] to try again.
  MoveResult move(int fromToken, int fromSegment, int toToken, int toSegment) {
    if (hasMoved) return MoveResult.invalid;
    final outcome = _simulateMove(_segments, fromToken, fromSegment, toToken, toSegment);
    if (outcome == null) return MoveResult.invalid;
    for (var i = 0; i < _segments.length; i++) {
      _segments[i] = outcome[i];
    }
    return MoveResult.moved;
  }

  /// Restores the original, unsolved layout.
  void reset() {
    for (var i = 0; i < _segments.length; i++) {
      final initial = _initialSegments[i];
      _segments[i] = initial == null ? null : Set<int>.of(initial);
    }
  }

  bool get isSolved => hasMoved && _winsAt(_segments);

  /// Every move from the *original* layout that would solve the puzzle —
  /// used for the in-game hint and to verify curated puzzles in tests.
  List<MatchMove> findSolutions() {
    final solutions = <MatchMove>[];
    for (var fi = 0; fi < _template.length; fi++) {
      final fromSegs = _initialSegments[fi];
      if (fromSegs == null) continue;
      for (final fromSeg in fromSegs) {
        for (var ti = 0; ti < _template.length; ti++) {
          if (_initialSegments[ti] == null) continue;
          for (var toSeg = 0; toSeg < 7; toSeg++) {
            final outcome =
                _simulateMove(_initialSegments, fi, fromSeg, ti, toSeg);
            if (outcome != null && _winsAt(outcome)) {
              solutions.add(MatchMove(fi, fromSeg, ti, toSeg));
            }
          }
        }
      }
    }
    return solutions;
  }

  bool _winsAt(List<Set<int>?> snapshot) {
    switch (type) {
      case MatchPuzzleType.fixEquation:
        return _equationHolds(snapshot);
      case MatchPuzzleType.differentDigit:
        final original = _digitForSegments(_initialSegments[0]!);
        final current = snapshot[0] == null ? null : _digitForSegments(snapshot[0]!);
        return current != null && current != original;
      case MatchPuzzleType.biggestNumber:
        final value = _numericValueOf(snapshot);
        return value != null && value == _maxReachableValue;
    }
  }

  bool _equationHolds(List<Set<int>?> snapshot) {
    if (_template.length != 5) return false;
    int? valueAt(int i) {
      final s = snapshot[i];
      return s == null ? null : _digitForSegments(s);
    }

    final a = valueAt(0);
    final b = valueAt(2);
    final c = valueAt(4);
    final op = _template[1].operator;
    final eq = _template[3].operator;
    if (a == null || b == null || c == null || eq != '=') return false;
    final lhs = op == '+' ? a + b : a - b;
    return lhs == c;
  }

  int? _numericValueOf(List<Set<int>?> snapshot) {
    var value = 0;
    for (final segs in snapshot) {
      final d = segs == null ? null : _digitForSegments(segs);
      if (d == null) return null;
      value = value * 10 + d;
    }
    return value;
  }

  int _computeMaxReachable() {
    var best = _numericValueOf(_segments) ?? -1;
    for (final outcome in _allLegalOutcomes(_segments)) {
      final value = _numericValueOf(outcome);
      if (value != null && value > best) best = value;
    }
    return best;
  }

  /// Every distinct legal single-move outcome from [snapshot] (used for
  /// [_computeMaxReachable]; [findSolutions] walks moves directly instead
  /// since it also needs to know *which* move produced a winning outcome).
  List<List<Set<int>?>> _allLegalOutcomes(List<Set<int>?> snapshot) {
    final outcomes = <List<Set<int>?>>[];
    for (var fi = 0; fi < snapshot.length; fi++) {
      final fromSegs = snapshot[fi];
      if (fromSegs == null) continue;
      for (final fromSeg in fromSegs) {
        for (var ti = 0; ti < snapshot.length; ti++) {
          if (snapshot[ti] == null) continue;
          for (var toSeg = 0; toSeg < 7; toSeg++) {
            final outcome = _simulateMove(snapshot, fi, fromSeg, ti, toSeg);
            if (outcome != null) outcomes.add(outcome);
          }
        }
      }
    }
    return outcomes;
  }

  /// Returns the segments after relocating one stick from (fi, fromSeg) to
  /// (ti, toSeg) within [snapshot], or null if that relocation is illegal
  /// (nothing to move, destination already lit, or either resulting shape
  /// isn't a real digit).
  List<Set<int>?>? _simulateMove(
    List<Set<int>?> snapshot,
    int fi,
    int fromSeg,
    int ti,
    int toSeg,
  ) {
    if (fi == ti && fromSeg == toSeg) return null;
    final fromSegs = snapshot[fi];
    final toSegs = snapshot[ti];
    if (fromSegs == null || toSegs == null) return null;
    if (!fromSegs.contains(fromSeg)) return null;

    final result = List<Set<int>?>.of(snapshot);
    if (fi == ti) {
      final newSegs = Set<int>.of(fromSegs)..remove(fromSeg);
      if (newSegs.contains(toSeg)) return null;
      newSegs.add(toSeg);
      if (_digitForSegments(newSegs) == null) return null;
      result[fi] = newSegs;
    } else {
      if (toSegs.contains(toSeg)) return null;
      final newFrom = Set<int>.of(fromSegs)..remove(fromSeg);
      final newTo = Set<int>.of(toSegs)..add(toSeg);
      if (_digitForSegments(newFrom) == null || _digitForSegments(newTo) == null) {
        return null;
      }
      result[fi] = newFrom;
      result[ti] = newTo;
    }
    return result;
  }

  /// A fresh curated set of puzzles — one factory call each so replaying
  /// never shares mutable state between rounds.
  static List<MatchstickPuzzle> bank() => [
    MatchstickPuzzle.fromNotation(
      '3+2=3',
      type: MatchPuzzleType.fixEquation,
      prompt: 'Move one matchstick to make the equation correct.',
    ),
    MatchstickPuzzle.fromNotation(
      '6+3=0',
      type: MatchPuzzleType.fixEquation,
      prompt: 'Move one matchstick to make the equation correct.',
    ),
    MatchstickPuzzle.fromNotation(
      '9-6=2',
      type: MatchPuzzleType.fixEquation,
      prompt: 'Move one matchstick to make the equation correct.',
    ),
    MatchstickPuzzle.fromNotation(
      '9-3=9',
      type: MatchPuzzleType.fixEquation,
      prompt: 'Move one matchstick to make the equation correct.',
    ),
    MatchstickPuzzle.fromNotation(
      '1-8=1',
      type: MatchPuzzleType.fixEquation,
      prompt: 'Move one matchstick to make the equation correct.',
    ),
    MatchstickPuzzle.fromNotation(
      '2',
      type: MatchPuzzleType.differentDigit,
      prompt: 'Move one matchstick to turn this into a different digit.',
    ),
    MatchstickPuzzle.fromNotation(
      '6',
      type: MatchPuzzleType.differentDigit,
      prompt: 'Move one matchstick to turn this into a different digit.',
    ),
    MatchstickPuzzle.fromNotation(
      '9',
      type: MatchPuzzleType.differentDigit,
      prompt: 'Move one matchstick to turn this into a different digit.',
    ),
    MatchstickPuzzle.fromNotation(
      '509',
      type: MatchPuzzleType.biggestNumber,
      prompt: 'Move one matchstick to make the biggest possible number.',
    ),
    MatchstickPuzzle.fromNotation(
      '177',
      type: MatchPuzzleType.biggestNumber,
      prompt: 'Move one matchstick to make the biggest possible number.',
    ),
    MatchstickPuzzle.fromNotation(
      '619',
      type: MatchPuzzleType.biggestNumber,
      prompt: 'Move one matchstick to make the biggest possible number.',
    ),
  ];
}
