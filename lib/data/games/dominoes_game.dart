import 'dart:math';

import 'package:meta/meta.dart';

/// Which open end of the domino layout a tile is being played onto.
enum DominoEnd { left, right }

/// Overall state of a [DominoesGame].
enum DominoStatus { playing, player0Won, player1Won, draw }

/// A single domino tile from the standard double-six set. Pips are stored as an
/// unordered pair, so `Domino(2, 5)` and `Domino(5, 2)` are the same tile.
class Domino {
  const Domino(this.a, this.b);

  final int a;
  final int b;

  bool get isDouble => a == b;
  int get pipSum => a + b;

  /// Whether this tile carries pip value [v] on either half.
  bool has(int v) => a == v || b == v;

  @override
  bool operator ==(Object other) =>
      other is Domino &&
      ((a == other.a && b == other.b) || (a == other.b && b == other.a));

  @override
  int get hashCode => Object.hashAll([min(a, b), max(a, b)]);

  @override
  String toString() => '[$a|$b]';
}

/// A tile placed in the layout, oriented so that reading the chain left→right,
/// each tile's [right] pip equals the next tile's [left] pip.
class PlacedDomino {
  const PlacedDomino(this.left, this.right, this.tile);

  final int left;
  final int right;
  final Domino tile;
}

/// A legal move: playing [tile] onto the given [end] of the layout.
class DominoMove {
  const DominoMove(this.tile, this.end);

  final Domino tile;
  final DominoEnd end;

  @override
  bool operator ==(Object other) =>
      other is DominoMove && other.tile == tile && other.end == end;

  @override
  int get hashCode => Object.hash(tile, end);
}

/// A local, pass-and-play Dominoes engine for exactly two players sharing one
/// device. NOT networked / "local mesh" multiplayer — both players take turns on
/// the same screen.
///
/// Ruleset (standard block dominoes, double-six set):
///   * 28 tiles (0-0 … 6-6); each player is dealt 7, the rest form the boneyard.
///   * The first move may be any tile and sets both open ends.
///   * A tile may be played on an end when one of its pips matches that end's
///     value; it attaches with the matching pip adjacent and exposes its other
///     pip as the new end value (a double keeps the same end value).
///   * A player who cannot play must draw from the boneyard until they can, or
///     until it is empty; with an empty boneyard and no legal move they pass.
///   * The hand that empties first wins ("domino"). If the game is blocked
///     (empty boneyard and neither player can move), the lower total pip count
///     wins; an equal count is a draw.
///
/// Flutter-free so move validation, orientation and scoring are unit-testable.
class DominoesGame {
  DominoesGame._({
    required this.hands,
    required this.boneyard,
    required this.layout,
    required int firstPlayer,
  }) : _currentPlayer = firstPlayer;

  /// Deals a fresh game. [random] is injectable for deterministic tests.
  factory DominoesGame.deal({Random? random, int firstPlayer = 0}) {
    final rng = random ?? Random();
    final tiles = <Domino>[
      for (var i = 0; i <= 6; i++)
        for (var j = i; j <= 6; j++) Domino(i, j),
    ]..shuffle(rng);

    final hand0 = tiles.sublist(0, 7);
    final hand1 = tiles.sublist(7, 14);
    final boneyard = tiles.sublist(14);

    return DominoesGame._(
      hands: [hand0, hand1],
      boneyard: boneyard,
      layout: <PlacedDomino>[],
      firstPlayer: firstPlayer,
    );
  }

  /// Builds a game from an explicit state, for deterministic tests of win /
  /// block scenarios that are impractical to reach through a random deal.
  @visibleForTesting
  factory DominoesGame.fromState({
    required List<List<Domino>> hands,
    required List<Domino> boneyard,
    List<PlacedDomino> layout = const [],
    int currentPlayer = 0,
  }) {
    return DominoesGame._(
      hands: hands,
      boneyard: boneyard,
      layout: List.of(layout),
      firstPlayer: currentPlayer,
    );
  }

  /// Each player's hand: `hands[0]` and `hands[1]`.
  final List<List<Domino>> hands;

  /// The face-down draw pile.
  final List<Domino> boneyard;

  /// The played chain, left→right.
  final List<PlacedDomino> layout;

  int _currentPlayer;
  DominoStatus _status = DominoStatus.playing;

  /// The player whose turn it is (0 or 1).
  int get currentPlayer => _currentPlayer;

  /// Current game status.
  DominoStatus get status => _status;

  /// The winning player (0 or 1), or `null` while playing or on a draw.
  int? get winner => switch (_status) {
    DominoStatus.player0Won => 0,
    DominoStatus.player1Won => 1,
    _ => null,
  };

  bool get isOver => _status != DominoStatus.playing;
  bool get isFirstMove => layout.isEmpty;

  /// Pip value exposed on the left end, or `null` before the first move.
  int? get leftEnd => layout.isEmpty ? null : layout.first.left;

  /// Pip value exposed on the right end, or `null` before the first move.
  int? get rightEnd => layout.isEmpty ? null : layout.last.right;

  /// Total pips remaining in [player]'s hand (used for blocked-game scoring).
  int handPipCount(int player) =>
      hands[player].fold(0, (sum, t) => sum + t.pipSum);

  /// Whether [tile] can legally be played onto [end] right now.
  bool canPlayTile(Domino tile, DominoEnd end) {
    if (isFirstMove) return true;
    final target = end == DominoEnd.left ? leftEnd! : rightEnd!;
    return tile.has(target);
  }

  /// All legal moves available to [player] given the current layout.
  List<DominoMove> legalMovesFor(int player) {
    final moves = <DominoMove>[];
    for (final tile in hands[player]) {
      if (isFirstMove) {
        moves.add(DominoMove(tile, DominoEnd.right));
        continue;
      }
      if (tile.has(leftEnd!)) moves.add(DominoMove(tile, DominoEnd.left));
      if (tile.has(rightEnd!)) moves.add(DominoMove(tile, DominoEnd.right));
    }
    return moves;
  }

  /// Whether [player] has at least one legal move.
  bool canPlay(int player) => legalMovesFor(player).isNotEmpty;

  /// Whether the game is blocked: empty boneyard and no legal move for either
  /// player (the trigger for lowest-pip scoring).
  bool get isBlocked =>
      boneyard.isEmpty && !canPlay(0) && !canPlay(1);

  /// Orients [tile] for placement against [existingEndValue].
  ///
  /// Returns `(outerPip, innerPip)` where `innerPip == existingEndValue` and
  /// `outerPip` becomes the new exposed end value.
  static (int outer, int inner) _orient(Domino tile, int existingEndValue) {
    if (tile.a == existingEndValue) return (tile.b, tile.a);
    return (tile.a, tile.b); // tile.b == existingEndValue
  }

  /// Plays [move] for the current player. Throws [StateError] if the move is
  /// illegal or the game is over. Advances the turn and resolves any win/block.
  void play(DominoMove move) {
    if (isOver) {
      throw StateError('Game is over');
    }
    final hand = hands[_currentPlayer];
    if (!hand.contains(move.tile)) {
      throw StateError('Tile ${move.tile} is not in player $_currentPlayer\'s '
          'hand');
    }
    if (!canPlayTile(move.tile, move.end)) {
      throw StateError('Illegal move: ${move.tile} on ${move.end}');
    }

    hand.remove(move.tile);

    if (isFirstMove) {
      layout.add(PlacedDomino(move.tile.a, move.tile.b, move.tile));
    } else if (move.end == DominoEnd.left) {
      final (outer, inner) = _orient(move.tile, leftEnd!);
      // Insert at the front so `left` reads as the new outer end.
      layout.insert(0, PlacedDomino(outer, inner, move.tile));
    } else {
      final (outer, inner) = _orient(move.tile, rightEnd!);
      layout.add(PlacedDomino(inner, outer, move.tile));
    }

    if (hand.isEmpty) {
      _status = _currentPlayer == 0
          ? DominoStatus.player0Won
          : DominoStatus.player1Won;
      return;
    }

    _advanceTurn();
  }

  /// Draws one tile from the boneyard into the current player's hand and returns
  /// it, or `null` if the boneyard is empty.
  Domino? draw() {
    if (isOver || boneyard.isEmpty) return null;
    final tile = boneyard.removeLast();
    hands[_currentPlayer].add(tile);
    return tile;
  }

  /// Passes the current player's turn. Only legal when they have no move and the
  /// boneyard is empty. Resolves the game if it is now blocked.
  void pass() {
    if (isOver) {
      throw StateError('Game is over');
    }
    if (boneyard.isNotEmpty) {
      throw StateError('Must draw before passing while the boneyard is stocked');
    }
    if (canPlay(_currentPlayer)) {
      throw StateError('Cannot pass with a legal move available');
    }
    _advanceTurn();
  }

  void _advanceTurn() {
    _currentPlayer = 1 - _currentPlayer;
    // If the game is now blocked (no draws left and neither can move), score it.
    if (isBlocked) _resolveBlocked();
  }

  void _resolveBlocked() {
    final p0 = handPipCount(0);
    final p1 = handPipCount(1);
    if (p0 < p1) {
      _status = DominoStatus.player0Won;
    } else if (p1 < p0) {
      _status = DominoStatus.player1Won;
    } else {
      _status = DominoStatus.draw;
    }
  }
}
