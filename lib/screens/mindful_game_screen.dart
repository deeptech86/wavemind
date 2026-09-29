import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_icon_button.dart';

/// "Calm Your Waves" mindfulness matching game (Figma node 10:5
/// "mindful-game"). A static translation of the board mid-session.
///
/// Reached from the guided-breathing screen (its info control), as the game is
/// an adjacent grounding activity within the app's mindfulness surface.
class MindfulGameScreen extends StatelessWidget {
  const MindfulGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          child: SizedBox.expand(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _Header(onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 24),
                  const _StatsRow(),
                  const SizedBox(height: 16),
                  const _Progress(),
                  const SizedBox(height: 24),
                  const _Board(),
                  const SizedBox(height: 24),
                  const _ActionRow(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlassIconButton(icon: AppAssets.arrowLeft, onTap: onBack),
            Flexible(
              child: Text(
                'Calm Your Waves',
                textAlign: TextAlign.center,
                style: AppTextStyles.headerTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GlassIconButton(
              icon: AppAssets.info,
              iconColor: AppColors.cream,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Soothing ocean pairs to quiet the mind',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.bodyMist),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FLOW TIMER',
                style: AppTextStyles.caption.copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SvgPicture.asset(AppAssets.clock, width: 14, height: 14),
                  const SizedBox(width: 6),
                  Text('04:12', style: AppTextStyles.statValue),
                ],
              ),
            ],
          ),
          Container(width: 1, height: 32, color: AppColors.glassBorder),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SWELL MATCHES',
                style: AppTextStyles.caption.copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                '8 / 16',
                style: AppTextStyles.statValue.copyWith(
                  color: AppColors.seafoam,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mind stillness progress', style: AppTextStyles.caption),
            Text('50%', style: AppTextStyles.badge.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.5,
            minHeight: 8,
            backgroundColor: AppColors.cardSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.seafoam),
          ),
        ),
      ],
    );
  }
}

enum _TileKind { down, faintShell, faintWaves, matched }

class _Board extends StatelessWidget {
  const _Board();

  static const List<List<_TileKind>> _layout = [
    [
      _TileKind.faintShell,
      _TileKind.down,
      _TileKind.down,
      _TileKind.faintShell,
    ],
    [_TileKind.matched, _TileKind.down, _TileKind.down, _TileKind.down],
    [
      _TileKind.down,
      _TileKind.faintWaves,
      _TileKind.faintWaves,
      _TileKind.matched,
    ],
    [_TileKind.down, _TileKind.down, _TileKind.down, _TileKind.down],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < _layout.length; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (var c = 0; c < _layout[r].length; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _GameTile(kind: _layout[r][c]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.kind});

  final _TileKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _TileKind.down:
        return _tile(
          color: AppColors.cardSurface,
          border: Border.all(color: AppColors.glassBorderSoft),
        );
      case _TileKind.faintShell:
        return Opacity(
          opacity: 0.4,
          child: _tile(
            color: AppColors.seafoamFaint,
            border: Border.all(color: AppColors.seafoamBorder),
            child: _icon(AppAssets.shell, AppColors.seafoam),
          ),
        );
      case _TileKind.faintWaves:
        return Opacity(
          opacity: 0.4,
          child: _tile(
            color: AppColors.seafoamFaint,
            border: Border.all(color: AppColors.seafoamBorder),
            child: _icon(AppAssets.waves, AppColors.seafoam),
          ),
        );
      case _TileKind.matched:
        return _tile(
          color: AppColors.teal,
          border: Border.all(color: AppColors.seafoam, width: 2),
          glow: true,
          child: _icon(AppAssets.anchor, AppColors.white),
        );
    }
  }

  Widget _tile({
    required Color color,
    required BoxBorder border,
    bool glow = false,
    Widget? child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: glow
            ? const [BoxShadow(color: AppColors.teal, blurRadius: 6)]
            : null,
      ),
      child: Center(child: child ?? const SizedBox.shrink()),
    );
  }

  Widget _icon(String asset, Color color) {
    return SvgPicture.asset(
      asset,
      width: 28,
      height: 28,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: AppAssets.sparkles,
            label: 'Hint',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionButton(
            icon: AppAssets.refreshCw,
            label: 'Shuffle',
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(icon, width: 16, height: 16),
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
