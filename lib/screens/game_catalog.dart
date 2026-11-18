import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../data/models/catalog_models.dart';
import '../theme/app_colors.dart';
import 'cabin_dominoes_screen.dart';
import 'fog_signal_echo_screen.dart';
import 'knot_master_screen.dart';
import 'matchstick_puzzle_screen.dart';
import 'mindful_game_screen.dart';
import 'sextant_horizon_screen.dart';
import 'stone_cairn_screen.dart';

/// Single source of truth for the seven built-in off-watch games — shared by
/// the full catalog ([off_watch_games_screen.dart]) and Haven's preview row
/// ([haven_screen.dart]) so they can never drift apart (e.g. Haven showing
/// placeholder game names that don't match what's actually playable).
class GameCatalogEntry {
  const GameCatalogEntry({
    required this.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.badge,
    required this.description,
    required this.meta,
    required this.ready,
    required this.screenBuilder,
  });

  final String key;
  final String icon;
  final Color accent;
  final String title;
  final String badge;
  final String description;
  final String meta;
  final bool ready;

  /// Builds the real game screen this entry opens into.
  final Widget Function() screenBuilder;
}

/// The seven built-in games, in default catalog order.
const List<GameCatalogEntry> gameCatalog = [
  GameCatalogEntry(
    key: GameKeys.calmYourWaves,
    icon: AppAssets.waves,
    accent: AppColors.seafoam,
    title: 'Calm Your Waves',
    badge: 'Ready',
    description:
        'Flash-and-recall memory match — the board flips face up for a '
        'moment, then you hunt for every pair from memory. Climbs from 4 '
        'tiles to the full 64.',
    meta: '2-32 pairs • Memory match',
    ready: true,
    screenBuilder: _buildCalmYourWaves,
  ),
  GameCatalogEntry(
    key: GameKeys.knotMaster,
    icon: AppAssets.anchor,
    accent: AppColors.teal,
    title: 'Knot Master 3D',
    badge: 'Ready',
    description:
        'Run the rope through every loop and close it clean — no crossing '
        'lines — with haptic feedback.',
    meta: 'Haptics on • 4-6m',
    ready: true,
    screenBuilder: _buildKnotMaster,
  ),
  GameCatalogEntry(
    key: GameKeys.fogSignalEcho,
    icon: AppAssets.cloudFog,
    accent: AppColors.sand,
    title: 'Fog Signal Echo',
    badge: 'Ready',
    description:
        'Call-and-repeat foghorn bearings — Bow, Starboard, Stern, Port — '
        'echoed back in a growing pattern.',
    meta: 'Pitch signals • 5-7m',
    ready: true,
    screenBuilder: _buildFogSignalEcho,
  ),
  GameCatalogEntry(
    key: GameKeys.sextantHorizon,
    icon: AppAssets.compass,
    accent: AppColors.seafoam,
    title: 'Sextant Horizon Balance',
    badge: 'Ready',
    description:
        'Gentle gyroscopic horizon leveler keeping the spirit bubble '
        'centered against swell roll.',
    meta: 'Gyro sensory • 3-5m',
    ready: true,
    screenBuilder: _buildSextantHorizon,
  ),
  GameCatalogEntry(
    key: GameKeys.cabinDominoes,
    icon: AppAssets.shell,
    accent: AppColors.sand,
    title: 'Cabin Dominoes',
    badge: 'Ready',
    description:
        'Cozy pass-and-play dominoes to challenge an off-watch crewmate on '
        'one device, no internet.',
    meta: 'Pass & play • 2 crew',
    ready: true,
    screenBuilder: _buildCabinDominoes,
  ),
  GameCatalogEntry(
    key: GameKeys.stoneCairn,
    icon: AppAssets.mapPin,
    accent: AppColors.muted,
    title: 'Stone Cairn Balance',
    badge: 'Ready',
    description:
        'Stack flattened river stones into a single balanced tower — stray '
        'too far off-center or stack a big stone on a small one and the '
        'whole tower topples.',
    meta: '7 stones • Balance tower',
    ready: true,
    screenBuilder: _buildStoneCairn,
  ),
  GameCatalogEntry(
    key: GameKeys.matchstickPuzzle,
    icon: AppAssets.lightbulbOff,
    accent: AppColors.stormRed,
    title: 'Matchstick Puzzle',
    badge: 'Ready',
    description:
        'Relocate exactly one matchstick — fix a false equation, find the '
        'biggest number in one move, or turn a digit into a different one.',
    meta: '1 move • Logic puzzle',
    ready: true,
    screenBuilder: _buildMatchstickPuzzle,
  ),
];

// Plain top-level functions (rather than inline closures above) so each
// screen's `const` constructor is actually used.
Widget _buildCalmYourWaves() => const MindfulGameScreen();
Widget _buildKnotMaster() => const KnotMasterScreen();
Widget _buildFogSignalEcho() => const FogSignalEchoScreen();
Widget _buildSextantHorizon() => const SextantHorizonScreen();
Widget _buildCabinDominoes() => const CabinDominoesScreen();
Widget _buildStoneCairn() => const StoneCairnScreen();
Widget _buildMatchstickPuzzle() => const MatchstickPuzzleScreen();

/// Picks a random-looking but deterministic [count] of [catalog] for the
/// week containing [date] — no persistence or backend needed. The same
/// local calendar week always yields the same picks (so it's stable across
/// app restarts/navigation within the week, and is also the offline
/// fallback before the server's real `featured_game` set has synced — see
/// `off_watch_games_screen.dart`), and the week's shuffle seed changes every
/// week, so which 2 come up doesn't walk a fixed order the way
/// `dailyLore`/`dailySounds` do — it genuinely varies week to week.
List<GameCatalogEntry> weeklyGames(
  DateTime date, {
  List<GameCatalogEntry> catalog = gameCatalog,
  int count = 2,
}) {
  if (catalog.isEmpty) return const [];
  final localMidnight = DateTime(date.year, date.month, date.day);
  final weekIndex = localMidnight.millisecondsSinceEpoch ~/ (7 * 86400000);
  final shuffled = List<GameCatalogEntry>.of(catalog)..shuffle(Random(weekIndex));
  final n = count < shuffled.length ? count : shuffled.length;
  return shuffled.sublist(0, n);
}
