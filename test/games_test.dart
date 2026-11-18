import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:wavemind_app/data/games/calm_your_waves.dart';
import 'package:wavemind_app/data/games/dominoes_game.dart';
import 'package:wavemind_app/data/games/fog_signal_echo.dart';
import 'package:wavemind_app/data/games/knot_puzzle.dart';
import 'package:wavemind_app/data/games/matchstick_puzzle.dart';
import 'package:wavemind_app/data/games/sextant_balance.dart';
import 'package:wavemind_app/data/games/stone_cairn.dart';

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

  // ---------------------------------------------------------------------------
  // Fog Signal Echo — call-and-repeat foghorn-bearing pattern memory.
  // ---------------------------------------------------------------------------

  group('FogSignalEcho', () {
    test('a fresh game has no rounds yet', () {
      final game = FogSignalEcho();
      expect(game.round, 0);
      expect(game.sequence, isEmpty);
      expect(game.isComplete, isFalse);
    });

    test('nextRound appends exactly one signal and resets echo position', () {
      final game = FogSignalEcho(random: Random(1));
      final first = game.nextRound();
      expect(game.round, 1);
      expect(game.sequence, [first]);
      expect(game.roundComplete, isFalse);
    });

    test('echoing the sequence correctly completes the round', () {
      final game = FogSignalEcho(random: Random(1));
      final signal = game.nextRound();
      expect(game.echo(signal), isTrue);
      expect(game.roundComplete, isTrue);
    });

    test('echoing the wrong signal does not advance and reports false', () {
      final game = FogSignalEcho(random: Random(1));
      final signal = game.nextRound();
      final wrong = FogSignal.values.firstWhere((s) => s != signal);
      expect(game.echo(wrong), isFalse);
      expect(game.roundComplete, isFalse);
    });

    test('a round must be echoed in order, not just as a set', () {
      final game = FogSignalEcho(random: Random(7));
      game.nextRound();
      game.nextRound(); // sequence now has 2 signals
      final seq = game.sequence;
      // Echoing the second signal first is wrong even though it's somewhere
      // in the sequence.
      expect(game.echo(seq[1]), isFalse);
    });

    test('retryRound replays the same sequence without growing it', () {
      final game = FogSignalEcho(random: Random(1));
      game.nextRound();
      game.nextRound();
      final seq = List.of(game.sequence);
      game.echo(seq[0]); // partial progress into the round
      game.retryRound();
      expect(game.sequence, seq); // unchanged
      expect(game.roundComplete, isFalse);
      // Echoing from the start again now works.
      for (final signal in seq) {
        expect(game.echo(signal), isTrue);
      }
      expect(game.roundComplete, isTrue);
    });

    test('isComplete once the sequence reaches targetRounds', () {
      final game = FogSignalEcho(targetRounds: 3, random: Random(1));
      game.nextRound();
      expect(game.isComplete, isFalse);
      game.nextRound();
      expect(game.isComplete, isFalse);
      game.nextRound();
      expect(game.isComplete, isTrue);
      expect(game.round, 3);
    });

    test('reset clears the sequence and echo position', () {
      final game = FogSignalEcho(random: Random(1));
      game.nextRound();
      game.nextRound();
      game.reset();
      expect(game.round, 0);
      expect(game.sequence, isEmpty);
    });

    test('sequence is unmodifiable', () {
      final game = FogSignalEcho(random: Random(1));
      game.nextRound();
      expect(() => game.sequence.add(FogSignal.bow), throwsUnsupportedError);
    });
  });

  // ---------------------------------------------------------------------------
  // Calm Your Waves — flash-and-recall memory match.
  // ---------------------------------------------------------------------------

  group('CalmYourWaves', () {
    test('level 0 starts at 2 pairs, the top level at 32 pairs', () {
      final first = CalmYourWaves.level(0, random: Random(1));
      expect(first.pairCount, 2);
      expect(first.tileCount, 4);

      final last = CalmYourWaves.level(
        CalmYourWaves.maxLevelIndex,
        random: Random(1),
      );
      expect(last.pairCount, 32);
      expect(last.tileCount, 64);
      expect(last.hasNextLevel, isFalse);
    });

    test('every design id appears in exactly two tiles', () {
      final game = CalmYourWaves.level(5, random: Random(7));
      final counts = <int, int>{};
      for (final d in game.designs) {
        counts[d] = (counts[d] ?? 0) + 1;
      }
      expect(counts.values, everyElement(2));
      expect(counts.keys.toSet(), {for (var i = 0; i < game.pairCount; i++) i});
    });

    test('tapping a matching pair matches both and they stay face up', () {
      final game = CalmYourWaves.level(0, random: Random(1));
      final design = game.designs[0];
      final partner = game.designs.indexOf(design, 1);

      expect(game.tap(0), CalmTapResult.picked);
      expect(game.tap(partner), CalmTapResult.matched);
      expect(game.isMatched(0), isTrue);
      expect(game.isMatched(partner), isTrue);
      expect(game.matchedPairs, 1);
      expect(game.isComplete, isFalse); // level 0 has 2 pairs; one remains
    });

    test('tapping a mismatched pair reveals both until cleared, then locks '
        'further taps', () {
      final game = CalmYourWaves.level(2, random: Random(3)); // 4 pairs
      // Find two tiles with different designs.
      var a = 0;
      var b = 1;
      while (game.designs[a] == game.designs[b]) {
        b++;
      }

      expect(game.tap(a), CalmTapResult.picked);
      final result = game.tap(b);
      expect(result, CalmTapResult.mismatch);
      expect(game.hasPendingMismatch, isTrue);
      expect(game.pendingMismatch, containsAll([a, b]));
      expect(game.isFaceUp(a), isTrue);
      expect(game.isFaceUp(b), isTrue);

      // Further taps are locked until the mismatch is cleared.
      final other = (List<int>.generate(game.tileCount, (i) => i)
            ..removeWhere((i) => i == a || i == b))
          .first;
      expect(game.tap(other), CalmTapResult.ignored);

      game.clearMismatch();
      expect(game.hasPendingMismatch, isFalse);
      expect(game.isFaceUp(a), isFalse);
      expect(game.isFaceUp(b), isFalse);
      expect(game.tap(other), CalmTapResult.picked);
    });

    test('tapping an already-matched or already-picked tile is ignored', () {
      final game = CalmYourWaves.level(1, random: Random(4));
      expect(game.tap(0), CalmTapResult.picked);
      expect(game.tap(0), CalmTapResult.ignored); // same tile twice
    });

    test('nextLevel advances pair count and resets progress', () {
      final level0 = CalmYourWaves.level(0, random: Random(1));
      final level1 = level0.nextLevel();
      expect(level1.levelIndex, 1);
      expect(level1.pairCount, 3);
      expect(level1.matchedPairs, 0);
      expect(level1.isComplete, isFalse);
    });

    test('retryLevel reshuffles the same level with progress reset', () {
      final game = CalmYourWaves.level(3, random: Random(9));
      game.tap(0);
      final retried = game.retryLevel();
      expect(retried.levelIndex, game.levelIndex);
      expect(retried.matchedPairs, 0);
      expect(retried.isFaceUp(0), isFalse);
    });

    test('restart always returns to level 0', () {
      final game = CalmYourWaves.level(8, random: Random(2));
      final restarted = game.restart();
      expect(restarted.levelIndex, 0);
      expect(restarted.pairCount, 2);
    });

    test('designs is unmodifiable', () {
      final game = CalmYourWaves.level(0, random: Random(1));
      expect(() => game.designs.add(0), throwsUnsupportedError);
    });
  });

  // ---------------------------------------------------------------------------
  // Stone Cairn Balance — drag-to-stack sandbox.
  // ---------------------------------------------------------------------------

  group('StoneCairn', () {
    test('generates the requested stone count, none placed, biggest first', () {
      final cairn = StoneCairn.generate(stoneCount: 7, random: Random(1));
      expect(cairn.stoneCount, 7);
      expect(cairn.placedCount, 0);
      expect(cairn.isComplete, isFalse);
      expect(cairn.stackOrder, isEmpty);
      expect(cairn.stones.every((s) => !cairn.isPlaced(s.id)), isTrue);
      // Biggest-first generation order (radii only trend downward, since
      // each is jittered a little for irregularity).
      expect(cairn.stones.first.radius, greaterThan(cairn.stones.last.radius));
    });

    test('dropping a stone joins the top of the tower', () {
      final cairn = StoneCairn.generate(stoneCount: 3, random: Random(2));
      expect(cairn.isPlaced(0), isFalse);

      cairn.dropOnTop(0);

      expect(cairn.isPlaced(0), isTrue);
      expect(cairn.stackOrder, [0]);
      expect(cairn.placedCount, 1);
      expect(cairn.fraction, closeTo(1 / 3, 1e-9));
    });

    test('each new drop joins on top, in drop order', () {
      final cairn = StoneCairn.generate(stoneCount: 3, random: Random(2));
      cairn.dropOnTop(2);
      cairn.dropOnTop(0);
      cairn.dropOnTop(1);

      expect(cairn.stackOrder, [2, 0, 1]); // bottom -> top, by drop order
    });

    test('re-dropping an already-placed stone moves it back to the top', () {
      final cairn = StoneCairn.generate(stoneCount: 3, random: Random(2));
      cairn.dropOnTop(0);
      cairn.dropOnTop(1);
      cairn.dropOnTop(2);
      expect(cairn.stackOrder, [0, 1, 2]);

      cairn.dropOnTop(0); // pick stone 0 back up, restack on top
      expect(cairn.stackOrder, [1, 2, 0]);
      expect(cairn.placedCount, 3); // still just 3 stones total
    });

    test('offsetFraction is clamped to [-1, 1] and drives the tilt', () {
      final cairn = StoneCairn.generate(stoneCount: 1, random: Random(2));
      cairn.dropOnTop(0, offsetFraction: 5.0); // way out of range
      expect(cairn.byId(0).offsetFraction, 1.0);

      cairn.dropOnTop(0, offsetFraction: -5.0);
      expect(cairn.byId(0).offsetFraction, -1.0);

      cairn.dropOnTop(0, offsetFraction: 0);
      expect(cairn.byId(0).tilt, closeTo(0, 0.05)); // just the jitter term
    });

    test('isComplete once every stone has joined the tower at least once', () {
      final cairn = StoneCairn.generate(stoneCount: 3, random: Random(3));
      cairn.dropOnTop(0);
      cairn.dropOnTop(1);
      expect(cairn.isComplete, isFalse);

      cairn.dropOnTop(2);
      expect(cairn.isComplete, isTrue);
      expect(cairn.fraction, 1.0);
    });

    test('newRound discards the tower and reshuffles unplaced', () {
      final cairn = StoneCairn.generate(stoneCount: 4, random: Random(4));
      cairn.dropOnTop(0);
      final fresh = cairn.newRound(random: Random(5));

      expect(fresh.stoneCount, cairn.stoneCount);
      expect(fresh.placedCount, 0);
      expect(fresh.stackOrder, isEmpty);
    });

    test('stacking roughly biggest-to-smallest, centered, stays stable', () {
      final cairn = StoneCairn.generate(stoneCount: 7, random: Random(6));
      // Generation order is already biggest-first.
      for (var id = 0; id < 7; id++) {
        final outcome = cairn.dropOnTop(id, offsetFraction: 0);
        expect(outcome, DropOutcome.stable, reason: 'stone $id');
      }
      expect(cairn.stackOrder.length, 7);
    });

    test('a meaningfully bigger stone on top of a much smaller one topples '
        'the tower', () {
      final cairn = StoneCairn.generate(stoneCount: 7, random: Random(6));
      // id 6 is the smallest (last generated), id 0 the biggest.
      expect(cairn.dropOnTop(6, offsetFraction: 0), DropOutcome.stable);
      final outcome = cairn.dropOnTop(0, offsetFraction: 0);
      expect(outcome, DropOutcome.unstable);
      // The drop still registers — collapse is a separate explicit step.
      expect(cairn.stackOrder, [6, 0]);
    });

    test('a stone leaning too far on top of another topples the tower, even '
        'when the size order is fine', () {
      final cairn = StoneCairn.generate(stoneCount: 7, random: Random(6));
      // id 0 (biggest) under id 1 (next biggest) is a perfectly normal size
      // order — only the lean should trip this.
      expect(cairn.dropOnTop(0, offsetFraction: 0), DropOutcome.stable);
      final outcome = cairn.dropOnTop(1, offsetFraction: 0.9);
      expect(outcome, DropOutcome.unstable);
    });

    test('the base stone tolerates more lean than a stacked stone before '
        'toppling', () {
      final cairn = StoneCairn.generate(stoneCount: 1, random: Random(6));
      // Between the stacked and ground lean limits: fine resting directly
      // on the ground, would not be if this were stone-on-stone.
      expect(cairn.dropOnTop(0, offsetFraction: 0.7), DropOutcome.stable);
      expect(cairn.dropOnTop(0, offsetFraction: 0.95), DropOutcome.unstable);
    });

    test('collapse empties the tower — every stone returns to the tray', () {
      final cairn = StoneCairn.generate(stoneCount: 7, random: Random(6));
      cairn.dropOnTop(6, offsetFraction: 0);
      final outcome = cairn.dropOnTop(0, offsetFraction: 0); // topples
      expect(outcome, DropOutcome.unstable);

      cairn.collapse();

      expect(cairn.stackOrder, isEmpty);
      expect(cairn.placedCount, 0);
      expect(cairn.isPlaced(0), isFalse);
      expect(cairn.isPlaced(6), isFalse);
      expect(cairn.stoneCount, 7); // the stones themselves are untouched
    });
  });

  // ---------------------------------------------------------------------------
  // Matchstick Puzzle — relocate one seven-segment stick.
  // ---------------------------------------------------------------------------

  group('MatchstickPuzzle', () {
    test('every curated bank puzzle is solvable in exactly one move', () {
      for (final puzzle in MatchstickPuzzle.bank()) {
        expect(
          puzzle.findSolutions(),
          isNotEmpty,
          reason: 'prompt: ${puzzle.prompt}',
        );
      }
    });

    test('fixEquation: solving the known move makes a false equation true', () {
      // "3+2=3" -> move the result digit's topRight stick to topLeft:
      // 3 (segments {0,2,3,5,6}) -> 5 (segments {0,1,3,5,6}).
      final puzzle = MatchstickPuzzle.fromNotation(
        '3+2=3',
        type: MatchPuzzleType.fixEquation,
        prompt: 'fix it',
      );
      expect(puzzle.isSolved, isFalse); // false equation, no move made yet

      final result = puzzle.move(4, 2, 4, 1);
      expect(result, MoveResult.moved);
      expect(puzzle.digitValueAt(4), 5);
      expect(puzzle.isSolved, isTrue); // 3+2=5
    });

    test('a move producing a broken (non-digit) shape is rejected', () {
      final puzzle = MatchstickPuzzle.fromNotation(
        '1-8=1',
        type: MatchPuzzleType.fixEquation,
        prompt: 'fix it',
      );
      // Token 0 is digit 1 ({2,5}); moving its topRight stick to topLeft
      // leaves {1,5}, which isn't any real digit.
      final result = puzzle.move(0, 2, 0, 1);
      expect(result, MoveResult.invalid);
      expect(puzzle.hasMoved, isFalse);
      expect(puzzle.digitValueAt(0), 1); // unchanged
    });

    test('cross-digit donation: a shed stick can complete a different token', () {
      // "1-8=1": the 8 (token 2) sheds its topRight stick, donated to the
      // first 1 (token 0)'s top slot -> 7 - 6 = 1, which is true.
      final puzzle = MatchstickPuzzle.fromNotation(
        '1-8=1',
        type: MatchPuzzleType.fixEquation,
        prompt: 'fix it',
      );
      final result = puzzle.move(2, 2, 0, 0);
      expect(result, MoveResult.moved);
      expect(puzzle.digitValueAt(0), 7);
      expect(puzzle.digitValueAt(2), 6);
      expect(puzzle.isSolved, isTrue); // 7-6=1
    });

    test('only one move is allowed per round', () {
      final puzzle = MatchstickPuzzle.fromNotation(
        '3+2=3',
        type: MatchPuzzleType.fixEquation,
        prompt: 'fix it',
      );
      expect(puzzle.move(4, 2, 4, 1), MoveResult.moved);
      // Any further move, even a no-op-shaped one, is rejected once moved.
      expect(puzzle.move(4, 1, 4, 2), MoveResult.invalid);
    });

    test('reset restores the original layout and clears hasMoved', () {
      final puzzle = MatchstickPuzzle.fromNotation(
        '3+2=3',
        type: MatchPuzzleType.fixEquation,
        prompt: 'fix it',
      );
      puzzle.move(4, 2, 4, 1);
      expect(puzzle.hasMoved, isTrue);

      puzzle.reset();
      expect(puzzle.hasMoved, isFalse);
      expect(puzzle.digitValueAt(4), 3);
      expect(puzzle.isSolved, isFalse);
    });

    test('differentDigit: moving a stick to a non-digit shape is rejected, '
        'a valid reshape solves it', () {
      final puzzle = MatchstickPuzzle.fromNotation(
        '2',
        type: MatchPuzzleType.differentDigit,
        prompt: 'different digit',
      );
      // 2 ({0,2,3,4,6}) -> 3 ({0,2,3,5,6}): move bottomLeft to bottomRight.
      final result = puzzle.move(0, 4, 0, 5);
      expect(result, MoveResult.moved);
      expect(puzzle.digitValueAt(0), 3);
      expect(puzzle.isSolved, isTrue);
    });

    test('differentDigit: 9 has two different valid single-move solutions', () {
      final puzzle = MatchstickPuzzle.fromNotation(
        '9',
        type: MatchPuzzleType.differentDigit,
        prompt: 'different digit',
      );
      final solutions = puzzle.findSolutions();
      final reachableDigits = <int>{};
      for (final move in solutions) {
        final fresh = MatchstickPuzzle.fromNotation(
          '9',
          type: MatchPuzzleType.differentDigit,
          prompt: 'different digit',
        );
        fresh.move(move.fromToken, move.fromSegment, move.toToken, move.toSegment);
        reachableDigits.add(fresh.digitValueAt(0)!);
      }
      expect(reachableDigits, containsAll([0, 6]));
    });

    test('biggestNumber: "177" is beatable, and the max is actually reached '
        'by at least one move', () {
      final puzzle = MatchstickPuzzle.fromNotation(
        '177',
        type: MatchPuzzleType.biggestNumber,
        prompt: 'biggest number',
      );
      final solutions = puzzle.findSolutions();
      expect(solutions, isNotEmpty);

      final move = solutions.first;
      puzzle.move(move.fromToken, move.fromSegment, move.toToken, move.toSegment);
      expect(puzzle.isSolved, isTrue);

      final value = [0, 1, 2]
          .map((i) => puzzle.digitValueAt(i))
          .fold<int>(0, (acc, d) => acc * 10 + d!);
      expect(value, greaterThan(177)); // strictly better than the start
    });

    test('biggestNumber: a non-maximal move is a legal relocation but '
        'leaves the puzzle unsolved', () {
      // "177": reshaping is impossible for 1/7, but donating the *wrong*
      // direction (there isn't one here) isn't available — instead verify
      // directly that an arbitrary non-winning outcome (if any exists)
      // never reports solved. Since both legal moves for "177" happen to
      // both win, assert against a puzzle with a clear non-winning move
      // instead: "619", reshaping the trailing 9 -> 6 is legal but not best.
      final puzzle = MatchstickPuzzle.fromNotation(
        '619',
        type: MatchPuzzleType.biggestNumber,
        prompt: 'biggest number',
      );
      final result = puzzle.move(2, 2, 2, 4); // 9 {0,1,2,3,5,6} -> 6 (swap topRight for bottomLeft)
      expect(result, MoveResult.moved);
      expect(puzzle.digitValueAt(2), 6);
      expect(puzzle.isSolved, isFalse); // "616" is not the max of "619"
    });
  });
}
