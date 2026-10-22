import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:tidewell_app/data/games/dominoes_game.dart';
import 'package:tidewell_app/data/games/knot_puzzle.dart';
import 'package:tidewell_app/data/games/sextant_balance.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Knot Master 3D — "close the loop without crossing" geometry + state machine.
  // ---------------------------------------------------------------------------

  /// A unit square plus centre — handy fixed layout for state-machine tests.
  /// Pivot (lowest y, tie-break lowest x) is id 0 at (0,0).
  List<KnotTarget> squareWithCentre() => const [
        KnotTarget(id: 0, position: Offset(0, 0)),
        KnotTarget(id: 1, position: Offset(1, 0)),
        KnotTarget(id: 2, position: Offset(1, 1)),
        KnotTarget(id: 3, position: Offset(0, 1)),
        KnotTarget(id: 4, position: Offset(0.5, 0.5)),
      ];

  /// True iff the closed cycle [order] (loop-id order, closing back to the
  /// first) has any pair of non-adjacent segments that properly cross.
  bool cycleHasCrossing(List<KnotTarget> targets, List<int> order) {
    Offset pos(int id) => targets.firstWhere((t) => t.id == id).position;
    final n = order.length;
    for (var i = 0; i < n; i++) {
      final a1 = order[i];
      final a2 = order[(i + 1) % n];
      for (var j = i + 1; j < n; j++) {
        final b1 = order[j];
        final b2 = order[(j + 1) % n];
        // Skip adjacent segments (those sharing a loop).
        if (a1 == b1 || a1 == b2 || a2 == b1 || a2 == b2) continue;
        if (KnotPuzzle.segmentsCross(pos(a1), pos(a2), pos(b1), pos(b2))) {
          return true;
        }
      }
    }
    return false;
  }

  group('KnotPuzzle.segmentsCross', () {
    test('an X of crossing diagonals is a crossing', () {
      expect(
        KnotPuzzle.segmentsCross(
          const Offset(0, 0),
          const Offset(1, 1),
          const Offset(0, 1),
          const Offset(1, 0),
        ),
        isTrue,
      );
    });

    test('parallel segments never cross', () {
      expect(
        KnotPuzzle.segmentsCross(
          const Offset(0, 0),
          const Offset(1, 0),
          const Offset(0, 1),
          const Offset(1, 1),
        ),
        isFalse,
      );
    });

    test('segments meeting only at a shared endpoint do not cross', () {
      // Adjacent path segments share a loop; that touch must not count.
      expect(
        KnotPuzzle.segmentsCross(
          const Offset(0, 0),
          const Offset(1, 1),
          const Offset(1, 1),
          const Offset(2, 0),
        ),
        isFalse,
      );
    });

    test('a T-junction (endpoint touching mid-segment) is not a proper cross',
        () {
      expect(
        KnotPuzzle.segmentsCross(
          const Offset(0, 0),
          const Offset(2, 0),
          const Offset(1, 0),
          const Offset(1, 1),
        ),
        isFalse,
      );
    });

    test('disjoint, far-apart segments do not cross', () {
      expect(
        KnotPuzzle.segmentsCross(
          const Offset(0, 0),
          const Offset(0, 1),
          const Offset(5, 5),
          const Offset(6, 6),
        ),
        isFalse,
      );
    });
  });

  group('KnotPuzzle layout generation', () {
    test('random layouts place the requested number of spaced loops', () {
      for (var seed = 0; seed < 20; seed++) {
        final puzzle = KnotPuzzle.random(random: Random(seed), loopCount: 5);
        expect(puzzle.targets, hasLength(5));
        expect(puzzle.targets.map((t) => t.id).toSet(), hasLength(5));
        // Every loop sits strictly inside the arena bounds.
        for (final t in puzzle.targets) {
          expect(t.position.dx, inInclusiveRange(0.0, 1.0));
          expect(t.position.dy, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('the pivot/polar-angle solution is never self-crossing', () {
      // The solvability guarantee: for any generated layout, the star-shaped
      // cycle the generator relies on admits a clean, non-crossing closed loop.
      for (var seed = 0; seed < 200; seed++) {
        final puzzle = KnotPuzzle.random(random: Random(seed), loopCount: 5);
        final cycle = KnotPuzzle.solutionCycle(puzzle.targets);
        expect(cycle, hasLength(puzzle.targets.length));
        expect(
          cycleHasCrossing(puzzle.targets, cycle),
          isFalse,
          reason: 'seed $seed produced a self-crossing solution',
        );
      }
    });

    test('the anchor is the solution pivot (its first loop)', () {
      for (var seed = 0; seed < 20; seed++) {
        final puzzle = KnotPuzzle.random(random: Random(seed));
        expect(puzzle.startId, KnotPuzzle.solutionCycle(puzzle.targets).first);
      }
    });
  });

  group('KnotPuzzle state machine', () {
    test('a fresh round starts seated on the anchor, in progress', () {
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      expect(puzzle.phase, KnotPhase.inProgress);
      expect(puzzle.startId, 0);
      expect(puzzle.currentEndId, 0);
      expect(puzzle.path, [0]);
      expect(puzzle.segmentsDrawn, 0);
      expect(puzzle.isLinked(0), isTrue);
    });

    test('every un-linked loop is a candidate (free order)', () {
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      expect(puzzle.isCandidate(0), isFalse); // the current end
      for (final id in [1, 2, 3, 4]) {
        expect(puzzle.isCandidate(id), isTrue);
      }
    });

    test('a clean connection extends the path and keeps it in progress', () {
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      expect(puzzle.connect(1), KnotStepResult.connected);
      expect(puzzle.path, [0, 1]);
      expect(puzzle.currentEndId, 1);
      expect(puzzle.segmentsDrawn, 1);
      expect(puzzle.isLinked(1), isTrue);
      expect(puzzle.phase, KnotPhase.inProgress);
    });

    test('re-linking a connected loop is rejected (no state change)', () {
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      puzzle.connect(1);
      expect(puzzle.connect(1), KnotStepResult.rejected);
      expect(puzzle.connect(0), KnotStepResult.rejected); // anchor, not yet
      expect(puzzle.path, [0, 1]);
    });

    test('a crossing pass fouls the knot and records the collision', () {
      // Perimeter order 0->1->2->3 is clean; jumping 3->... we instead force a
      // cross: 0->2 (diagonal), then 1 so 2->1 is fine, then 3 so 1->3 crosses
      // the 0->2 diagonal. Build it directly:
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      expect(puzzle.connect(2), KnotStepResult.connected); // 0->2 diagonal
      expect(puzzle.connect(1), KnotStepResult.connected); // 2->1
      // 1->3 crosses the 0->2 diagonal.
      expect(puzzle.connect(3), KnotStepResult.overlap);
      expect(puzzle.phase, KnotPhase.failed);
      expect(puzzle.isFailed, isTrue);
      final crossing = puzzle.crossing;
      expect(crossing, isNotNull);
      expect(crossing!.newSegment, const KnotSegment(1, 3));
      expect(crossing.hitSegment, const KnotSegment(0, 2));
      // Fouled rounds reject further moves.
      expect(puzzle.connect(4), KnotStepResult.rejected);
    });

    test('an adjacent segment sharing the current end never false-fouls', () {
      // Linking straight along the perimeter: each new pass shares the end
      // loop with the previous one but must not register as a crossing.
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      expect(puzzle.connect(1), KnotStepResult.connected);
      expect(puzzle.connect(2), KnotStepResult.connected);
      expect(puzzle.connect(3), KnotStepResult.connected);
      expect(puzzle.phase, KnotPhase.inProgress);
    });

    test('closing is only offered once every loop is linked', () {
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      puzzle.connect(1);
      puzzle.connect(2);
      puzzle.connect(3);
      expect(puzzle.canClose, isFalse); // loop 4 still open
      expect(puzzle.isCandidate(0), isFalse);
      expect(puzzle.connect(4), KnotStepResult.connected);
      expect(puzzle.canClose, isTrue);
      expect(puzzle.allLinked, isTrue);
      // Now the only candidate is the anchor.
      expect(puzzle.isCandidate(0), isTrue);
      for (final id in [1, 2, 3]) {
        expect(puzzle.isCandidate(id), isFalse);
      }
    });

    test('a clean closed loop through every point secures the knot', () {
      final puzzle = KnotPuzzle.fromTargets(squareWithCentre());
      // Perimeter then centre, ordered so the closing pass stays clean:
      // 0->1->2->3 around the square, 3->4 to the centre, 4->0 closes.
      expect(puzzle.connect(1), KnotStepResult.connected);
      expect(puzzle.connect(2), KnotStepResult.connected);
      expect(puzzle.connect(3), KnotStepResult.connected);
      expect(puzzle.connect(4), KnotStepResult.connected);
      expect(puzzle.connect(0), KnotStepResult.closed);
      expect(puzzle.phase, KnotPhase.success);
      expect(puzzle.isSuccess, isTrue);
      expect(puzzle.fraction, 1.0);
      expect(puzzle.segmentsDrawn, puzzle.totalSegments);
      // Secured rounds reject further moves.
      expect(puzzle.connect(1), KnotStepResult.rejected);
    });

    test('the solution cycle always plays out to success live', () {
      // Validity is checked live, not against a precomputed answer — but the
      // generator's own solution order must, of course, pass that live check.
      for (var seed = 0; seed < 50; seed++) {
        final puzzle = KnotPuzzle.random(random: Random(seed), loopCount: 5);
        final cycle = KnotPuzzle.solutionCycle(puzzle.targets);
        // cycle[0] == startId; play the rest, then close.
        for (var i = 1; i < cycle.length; i++) {
          expect(
            puzzle.connect(cycle[i]),
            KnotStepResult.connected,
            reason: 'seed $seed step $i',
          );
        }
        expect(puzzle.connect(puzzle.startId), KnotStepResult.closed,
            reason: 'seed $seed close');
        expect(puzzle.isSuccess, isTrue);
      }
    });

    test('a closing pass that would cross fouls instead of securing', () {
      // Four loops where the order 0->1->2->3 links cleanly but the closing
      // pass 3->0 crosses the 1->2 segment — verifies the close itself is
      // crossing-checked, not just the intermediate links.
      //   0=(0,0) 1=(1,0) 2=(1/3,2/3) 3=(2/3,2/3)
      // 3->0 runs along y=x and meets 1->2 at (0.5,0.5).
      final targets = const [
        KnotTarget(id: 0, position: Offset(0, 0)),
        KnotTarget(id: 1, position: Offset(1, 0)),
        KnotTarget(id: 2, position: Offset(1 / 3, 2 / 3)),
        KnotTarget(id: 3, position: Offset(2 / 3, 2 / 3)),
      ];
      final puzzle = KnotPuzzle.fromTargets(targets, startId: 0);
      expect(puzzle.connect(1), KnotStepResult.connected); // 0->1
      expect(puzzle.connect(2), KnotStepResult.connected); // 1->2
      expect(puzzle.connect(3), KnotStepResult.connected); // 2->3
      expect(puzzle.canClose, isTrue);
      // Closing 3->0 crosses the earlier 1->2 segment.
      expect(puzzle.connect(0), KnotStepResult.overlap);
      expect(puzzle.isFailed, isTrue);
      expect(puzzle.crossing!.newSegment, const KnotSegment(3, 0));
      expect(puzzle.crossing!.hitSegment, const KnotSegment(1, 2));
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
