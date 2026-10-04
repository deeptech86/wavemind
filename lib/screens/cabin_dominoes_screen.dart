import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/games/dominoes_game.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';

/// "Cabin Dominoes" — a local, pass-and-play two-player dominoes game.
///
/// IMPORTANT: this is pass-and-play on ONE device (crewmates take turns on the
/// same screen behind a privacy hand-off), NOT networked / Bluetooth "local
/// mesh" multiplayer. Cribbage is not included in this pass.
///
/// All rules live in the Flutter-free [DominoesGame] engine; this screen is the
/// presentation + turn/hand-off shell. Awards no Fleet Knots.
class CabinDominoesScreen extends StatefulWidget {
  const CabinDominoesScreen({super.key});

  @override
  State<CabinDominoesScreen> createState() => _CabinDominoesScreenState();
}

class _CabinDominoesScreenState extends State<CabinDominoesScreen> {
  late DominoesGame _game = DominoesGame.deal();

  /// While true, the current player's hand is hidden behind a hand-off screen so
  /// the previous player can pass the device without peeking.
  bool _awaitingHandoff = false;

  /// A tile the player tapped that can go on either end, awaiting a choice.
  Domino? _pendingTile;

  void _newGame() {
    HapticFeedback.selectionClick();
    setState(() {
      _game = DominoesGame.deal();
      _awaitingHandoff = false;
      _pendingTile = null;
    });
  }

  void _playTile(Domino tile) {
    final moves = _game
        .legalMovesFor(_game.currentPlayer)
        .where((m) => m.tile == tile)
        .toList();
    if (moves.isEmpty) return;

    if (moves.length == 1) {
      _commitMove(moves.first);
    } else {
      // Playable on both ends — ask which.
      setState(() => _pendingTile = tile);
    }
  }

  void _commitMove(DominoMove move) {
    final before = _game.currentPlayer;
    setState(() {
      _game.play(move);
      _pendingTile = null;
      if (!_game.isOver && _game.currentPlayer != before) {
        _awaitingHandoff = true;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _draw() {
    HapticFeedback.selectionClick();
    setState(() => _game.draw());
  }

  void _pass() {
    final before = _game.currentPlayer;
    setState(() {
      _game.pass();
      if (!_game.isOver && _game.currentPlayer != before) {
        _awaitingHandoff = true;
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _revealHand() {
    HapticFeedback.selectionClick();
    setState(() => _awaitingHandoff = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Cabin Dominoes'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PassPlayNotice(),
                      const SizedBox(height: 16),
                      if (_game.isOver)
                        _ResultBanner(game: _game, onNewGame: _newGame)
                      else if (_awaitingHandoff)
                        _HandoffCard(
                          player: _game.currentPlayer,
                          onReveal: _revealHand,
                        )
                      else
                        _TurnView(
                          game: _game,
                          pendingTile: _pendingTile,
                          onPlayTile: _playTile,
                          onCommit: _commitMove,
                          onCancelPending: () =>
                              setState(() => _pendingTile = null),
                          onDraw: _draw,
                          onPass: _pass,
                        ),
                      const SizedBox(height: 16),
                      _BoardSection(game: _game),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassPlayNotice extends StatelessWidget {
  const _PassPlayNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, size: 18, color: AppColors.sand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pass-and-play on one device — hand it to your crewmate each '
              'turn. No internet, no mesh needed.',
              style: AppTextStyles.caption.copyWith(color: AppColors.cream),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoffCard extends StatelessWidget {
  const _HandoffCard({required this.player, required this.onReveal});

  final int player;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.seafoamBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.swap_horiz, size: 40, color: AppColors.seafoam),
          const SizedBox(height: 12),
          Text(
            'Pass to Crew ${player + 1}',
            style: AppTextStyles.cardHeading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Keep the tiles hidden from the other crewmate until it is your '
            'turn.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.seafoam,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              child: InkWell(
                onTap: onReveal,
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      "I'm Crew ${player + 1} — reveal my hand",
                      style: AppTextStyles.buttonLarge,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({
    required this.game,
    required this.pendingTile,
    required this.onPlayTile,
    required this.onCommit,
    required this.onCancelPending,
    required this.onDraw,
    required this.onPass,
  });

  final DominoesGame game;
  final Domino? pendingTile;
  final ValueChanged<Domino> onPlayTile;
  final ValueChanged<DominoMove> onCommit;
  final VoidCallback onCancelPending;
  final VoidCallback onDraw;
  final VoidCallback onPass;

  @override
  Widget build(BuildContext context) {
    final player = game.currentPlayer;
    final hand = game.hands[player];
    final legal = game.legalMovesFor(player).map((m) => m.tile).toSet();
    final canPlay = legal.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.seafoamFaint,
            borderRadius: BorderRadius.circular(AppTheme.radiusTile),
            border: Border.all(color: AppColors.seafoamBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, size: 18, color: AppColors.seafoam),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Crew ${player + 1}\'s turn',
                  style: AppTextStyles.cardTitleSmall,
                ),
              ),
              Text(
                'Boneyard: ${game.boneyard.length}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (pendingTile != null)
          _EndChooser(
            tile: pendingTile!,
            game: game,
            onCommit: onCommit,
            onCancel: onCancelPending,
          )
        else
          Text(
            canPlay
                ? 'Tap a lit tile to play it.'
                : game.boneyard.isNotEmpty
                    ? 'No move — draw from the boneyard.'
                    : 'No move and the boneyard is empty — pass.',
            style: AppTextStyles.caption.copyWith(color: AppColors.cream),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tile in hand)
              _HandTile(
                tile: tile,
                playable: legal.contains(tile),
                onTap: legal.contains(tile) ? () => onPlayTile(tile) : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!canPlay)
          _ActionButton(
            label: game.boneyard.isNotEmpty ? 'Draw a tile' : 'Pass turn',
            icon: game.boneyard.isNotEmpty
                ? Icons.download_outlined
                : Icons.skip_next,
            onTap: game.boneyard.isNotEmpty ? onDraw : onPass,
          ),
      ],
    );
  }
}

class _EndChooser extends StatelessWidget {
  const _EndChooser({
    required this.tile,
    required this.game,
    required this.onCommit,
    required this.onCancel,
  });

  final Domino tile;
  final DominoesGame game;
  final ValueChanged<DominoMove> onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealFaintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Play $tile on which end?',
            style: AppTextStyles.bodyStrong,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Left (${game.leftEnd})',
                  icon: Icons.arrow_back,
                  onTap: () => onCommit(DominoMove(tile, DominoEnd.left)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Right (${game.rightEnd})',
                  icon: Icons.arrow_forward,
                  onTap: () => onCommit(DominoMove(tile, DominoEnd.right)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel',
              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardSection extends StatelessWidget {
  const _BoardSection({required this.game});

  final DominoesGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE LINE', style: AppTextStyles.badge.copyWith(
            color: AppColors.sand,
          )),
          const SizedBox(height: 10),
          if (game.layout.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Empty table — play the first tile.',
                  style: AppTextStyles.caption,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final placed in game.layout) ...[
                    _LaidTile(placed: placed),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A tile placed on the line, drawn horizontally (left pip | right pip).
class _LaidTile extends StatelessWidget {
  const _LaidTile({required this.placed});

  final PlacedDomino placed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          _PipFace(value: placed.left, dark: true),
          Container(width: 1, height: 36, color: AppColors.deepNavy),
          _PipFace(value: placed.right, dark: true),
        ],
      ),
    );
  }
}

/// A tile in the player's hand, drawn horizontally; dimmed when unplayable.
class _HandTile extends StatelessWidget {
  const _HandTile({
    required this.tile,
    required this.playable,
    required this.onTap,
  });

  final Domino tile;
  final bool playable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: playable ? AppColors.seafoam : AppColors.glassBorder,
          width: playable ? 2.5 : 1,
        ),
        boxShadow: playable
            ? [
                BoxShadow(
                  color: AppColors.seafoam.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PipFace(value: tile.a, dark: true),
          Container(width: 1, height: 42, color: AppColors.deepNavy),
          _PipFace(value: tile.b, dark: true),
        ],
      ),
    );

    final tile0 = Opacity(opacity: playable ? 1 : 0.45, child: content);
    if (onTap == null) return tile0;
    return GestureDetector(onTap: onTap, child: tile0);
  }
}

/// A single domino face rendering [value] pips (0–6) in the standard 3×3 layout.
class _PipFace extends StatelessWidget {
  const _PipFace({required this.value, this.dark = false});

  final int value;
  final bool dark;

  static const Map<int, List<int>> _patterns = {
    0: [],
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final lit = _patterns[value] ?? const <int>[];
    final color = dark ? AppColors.deepNavy : AppColors.cream;
    return SizedBox(
      width: 42,
      height: 42,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 9; i++)
              Center(
                child: lit.contains(i)
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.game, required this.onNewGame});

  final DominoesGame game;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final winner = game.winner;
    final isDraw = game.status == DominoStatus.draw;
    final title = isDraw ? 'Blocked — a draw' : 'Crew ${winner! + 1} wins!';
    final subtitle = isDraw
        ? 'Even pip counts. Deal another hand.'
        : 'Lowest line, cleanest hand. Deal another?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.seafoamFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.seafoamBorder),
      ),
      child: Column(
        children: [
          Icon(
            isDraw ? Icons.handshake_outlined : Icons.emoji_events,
            size: 40,
            color: AppColors.seafoam,
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.cardHeading,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.caption,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Crew 1 pips: ${game.handPipCount(0)}   •   '
            'Crew 2 pips: ${game.handPipCount(1)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.seafoam,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              child: InkWell(
                onTap: onNewGame,
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text('New Game', style: AppTextStyles.buttonLarge),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
