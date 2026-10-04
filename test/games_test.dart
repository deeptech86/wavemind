import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/data/games/dominoes_game.dart';
import 'package:tidewell_app/data/games/knot_puzzle.dart';
import 'package:tidewell_app/data/games/sextant_balance.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Knot Master 3D — threading-sequence correctness.
  // ---------------------------------------------------------------------------
  group('KnotPuzzle', () {
    test('shuffled produces a valid, complete, non-repeating order', () {
      final puzzle = KnotPuzzle.shuffled(random: Random(1));
      expect(puzzle.order.length, puzzle.targets.length);
      expect(puzzle.order.toSet().length, puzzle.order.length);
      for (final id in puzzle.order) {
        expect(puzzle.targets.any((t) => t.id == id), isTrue);
      }
      expect(puzzle.progress, 0);
      expect(puzzle.isComplete, isFalse);
    });

    test('a correct target advances progress', () {
      final puzzle = KnotPuzzle.shuffled(random: Random(2));
      final first = puzzle.order.first;
      expect(puzzle.registerTarget(first), KnotStepResult.correct);
      expect(puzzle.progress, 1);
      expect(puzzle.isThreaded(first), isTrue);
    });

    test('a wrong target is a foul move that does not advance', () {
      final puzzle = KnotPuzzle.shuffled(random: Random(3));
      final wrong = puzzle.order.last; // not the first step
      expect(puzzle.registerTarget(wrong), KnotStepResult.wrong);
      expect(puzzle.progress, 0);
      expect(puzzle.isThreaded(wrong), isFalse);
    });

    test('threading the full order in sequence completes the knot', () {
      final puzzle = KnotPuzzle.shuffled(random: Random(4));
      final order = List<int>.of(puzzle.order);
      for (var i = 0; i < order.length; i++) {
        final result = puzzle.registerTarget(order[i]);
        if (i == order.length - 1) {
          expect(result, KnotStepResult.completed);
        } else {
          expect(result, KnotStepResult.correct);
        }
      }
      expect(puzzle.isComplete, isTrue);
      expect(puzzle.fraction, 1.0);
      expect(puzzle.nextTargetId, isNull);
    });

    test('reset restores a fresh round with the same layout', () {
      final puzzle = KnotPuzzle.shuffled(random: Random(5));
      puzzle.registerTarget(puzzle.order.first);
      puzzle.reset();
      expect(puzzle.progress, 0);
      expect(puzzle.isComplete, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Sextant Horizon Balance — tilt mapping + calm-meter accumulation.
  // ---------------------------------------------------------------------------
  group('SextantBalance', () {
    test('a level device keeps the bubble centred', () {
      final b = SextantBalance();
      final bubble = b.bubbleOffset(0, 0);
      expect(bubble, Offset.zero);
      expect(b.isCentered(bubble), isTrue);
    });

    test('bubble offset clamps to the vial and flips the y axis', () {
      final b = SextantBalance(sensitivity: 0.11);
      final bubble = b.bubbleOffset(100, 100); // far past the rim
      expect(bubble.dx, 1.0);
      expect(bubble.dy, -1.0); // y is inverted for a spirit-level feel
    });

    test('a strong tilt leaves the tolerance zone', () {
      final b = SextantBalance(tolerance: 0.18, sensitivity: 0.11);
      final bubble = b.bubbleOffset(9.8, 0); // ~1g on one axis
      expect(b.isCentered(bubble), isFalse);
    });

    test('holding centred fills the calm meter to completion', () {
      final b = SextantBalance(targetHold: const Duration(seconds: 2));
      b.tick(const Duration(seconds: 1), centered: true);
      expect(b.progress, closeTo(0.5, 0.001));
      expect(b.isComplete, isFalse);
      b.tick(const Duration(seconds: 1), centered: true);
      expect(b.progress, 1.0);
      expect(b.isComplete, isTrue);
    });

    test('drifting off-centre drains the meter (scaled by decay)', () {
      final b = SextantBalance(
        targetHold: const Duration(seconds: 10),
        decayFactor: 0.5,
      );
      b.tick(const Duration(seconds: 4), centered: true); // 4s held
      final filled = b.progress;
      b.tick(const Duration(seconds: 2), centered: false); // drain 1s worth
      expect(b.progress, lessThan(filled));
    });

    test('meter never goes negative', () {
      final b = SextantBalance(targetHold: const Duration(seconds: 5));
      b.tick(const Duration(seconds: 10), centered: false);
      expect(b.progress, 0.0);
    });

    test('reset empties the meter', () {
      final b = SextantBalance(targetHold: const Duration(seconds: 2));
      b.tick(const Duration(seconds: 2), centered: true);
      b.reset();
      expect(b.progress, 0.0);
      expect(b.isComplete, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Cabin Dominoes — move validation, orientation, win + block scoring.
  // ---------------------------------------------------------------------------
  group('Domino', () {
    test('equality is order-independent', () {
      expect(const Domino(2, 5), const Domino(5, 2));
      expect(const Domino(2, 5).hashCode, const Domino(5, 2).hashCode);
      expect(const Domino(2, 5) == const Domino(2, 4), isFalse);
    });

    test('has / isDouble / pipSum', () {
      expect(const Domino(3, 3).isDouble, isTrue);
      expect(const Domino(3, 5).has(5), isTrue);
      expect(const Domino(3, 5).has(2), isFalse);
      expect(const Domino(3, 5).pipSum, 8);
    });
  });

  group('DominoesGame.deal', () {
    test('deals 7 + 7 hands and a 14-tile boneyard from a full set', () {
      final game = DominoesGame.deal(random: Random(7));
      expect(game.hands[0], hasLength(7));
      expect(game.hands[1], hasLength(7));
      expect(game.boneyard, hasLength(14));

      final all = [
        ...game.hands[0],
        ...game.hands[1],
        ...game.boneyard,
      ];
      expect(all.toSet(), hasLength(28)); // all 28 tiles, no duplicates
    });
  });

  group('DominoesGame move validation', () {
    test('any tile is legal on the first move and sets both ends', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(2, 5)],
          [const Domino(0, 0)],
        ],
        boneyard: [const Domino(1, 1)],
      );
      expect(game.isFirstMove, isTrue);
      expect(game.canPlayTile(const Domino(2, 5), DominoEnd.right), isTrue);
      game.play(const DominoMove(Domino(2, 5), DominoEnd.right));
      expect(game.leftEnd, 2);
      expect(game.rightEnd, 5);
    });

    test('a tile matches an end only when a pip matches', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(5, 6), const Domino(1, 2)],
          [const Domino(0, 0)],
        ],
        boneyard: [],
        layout: const [PlacedDomino(2, 5, Domino(2, 5))],
      );
      // rightEnd = 5, leftEnd = 2.
      expect(game.canPlayTile(const Domino(5, 6), DominoEnd.right), isTrue);
      expect(game.canPlayTile(const Domino(5, 6), DominoEnd.left), isFalse);
      expect(game.canPlayTile(const Domino(1, 2), DominoEnd.left), isTrue);
      final moves = game.legalMovesFor(0);
      expect(moves, contains(const DominoMove(Domino(5, 6), DominoEnd.right)));
      expect(moves, contains(const DominoMove(Domino(1, 2), DominoEnd.left)));
    });

    test('playing on the right end exposes the non-matching pip', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(5, 6)],
          [const Domino(0, 0)],
        ],
        boneyard: [const Domino(1, 1)],
        layout: const [PlacedDomino(2, 5, Domino(2, 5))],
      );
      game.play(const DominoMove(Domino(5, 6), DominoEnd.right));
      expect(game.rightEnd, 6); // 5 matched, 6 now exposed
      expect(game.leftEnd, 2);
    });

    test('playing on the left end exposes the non-matching pip', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(1, 2)],
          [const Domino(0, 0)],
        ],
        boneyard: [const Domino(1, 1)],
        layout: const [PlacedDomino(2, 5, Domino(2, 5))],
      );
      game.play(const DominoMove(Domino(1, 2), DominoEnd.left));
      expect(game.leftEnd, 1); // 2 matched, 1 now exposed
      expect(game.rightEnd, 5);
    });

    test('an illegal move throws', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(0, 1)],
          [const Domino(0, 0)],
        ],
        boneyard: [],
        layout: const [PlacedDomino(2, 5, Domino(2, 5))],
      );
      expect(
        () => game.play(const DominoMove(Domino(0, 1), DominoEnd.right)),
        throwsStateError,
      );
    });
  });

  group('DominoesGame outcomes', () {
    test('emptying your hand wins immediately', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(5, 6)],
          [const Domino(0, 0)],
        ],
        boneyard: [],
        layout: const [PlacedDomino(2, 5, Domino(2, 5))],
      );
      game.play(const DominoMove(Domino(5, 6), DominoEnd.right));
      expect(game.isOver, isTrue);
      expect(game.winner, 0);
      expect(game.status, DominoStatus.player0Won);
    });

    test('drawing moves a tile from boneyard to hand', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(0, 1)],
          [const Domino(0, 0)],
        ],
        boneyard: [const Domino(3, 3)],
        layout: const [PlacedDomino(5, 6, Domino(5, 6))],
      );
      expect(game.canPlay(0), isFalse);
      final drawn = game.draw();
      expect(drawn, const Domino(3, 3));
      expect(game.hands[0], hasLength(2));
      expect(game.boneyard, isEmpty);
    });

    test('a blocked game is scored to the lowest pip count', () {
      // Neither player can play on ends 5/6, boneyard empty.
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(0, 1)], // 1 pip
          [const Domino(3, 4)], // 7 pips
        ],
        boneyard: [],
        layout: const [PlacedDomino(5, 6, Domino(5, 6))],
      );
      expect(game.isBlocked, isTrue);
      game.pass(); // player 0 passes -> player 1 also blocked -> resolve
      expect(game.isOver, isTrue);
      expect(game.winner, 0); // 1 pip < 7 pips
    });

    test('equal pip counts on a block is a draw', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(0, 1)],
          [const Domino(0, 1)],
        ],
        boneyard: [],
        layout: const [PlacedDomino(5, 6, Domino(5, 6))],
      );
      game.pass();
      expect(game.status, DominoStatus.draw);
      expect(game.winner, isNull);
    });

    test('passing with a legal move available is rejected', () {
      final game = DominoesGame.fromState(
        hands: [
          [const Domino(5, 2)],
          [const Domino(0, 0)],
        ],
        boneyard: [],
        layout: const [PlacedDomino(5, 6, Domino(5, 6))],
      );
      expect(() => game.pass(), throwsStateError);
    });
  });
}
