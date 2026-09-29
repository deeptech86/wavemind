import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../screens/community_connect_screen.dart';
import '../screens/haven_screen.dart';
import '../screens/journal_entry_screen.dart';
import '../screens/weekly_insights_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The five destinations of the persistent bottom navigation bar.
enum TideTab { helm, breathe, log, crew, insights }

/// Shared bottom navigation used by the dashboard and the primary feature
/// screens. Selecting a tab returns to the dashboard root and (for non-Helm
/// tabs) pushes the destination, so the back stack stays shallow
/// (dashboard → section) and hardware back always returns to the Helm.
class TideBottomNav extends StatelessWidget {
  const TideBottomNav({super.key, required this.active});

  /// The tab that should render in its active (seafoam) state.
  final TideTab active;

  void _go(BuildContext context, TideTab tab) {
    // Helm always routes home; other tabs no-op when already selected.
    if (tab == active && tab != TideTab.helm) return;

    final navigator = Navigator.of(context);
    // Collapse back to the dashboard (the first route after Welcome).
    navigator.popUntil((route) => route.isFirst);

    Widget? destination;
    switch (tab) {
      case TideTab.helm:
        return; // Already back at the dashboard.
      case TideTab.breathe:
        destination = const HavenScreen();
      case TideTab.log:
        destination = const JournalEntryScreen();
      case TideTab.crew:
        destination = const CommunityConnectScreen();
      case TideTab.insights:
        destination = const WeeklyInsightsScreen();
    }
    navigator.push(MaterialPageRoute<void>(builder: (_) => destination!));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBarBackground,
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: AppAssets.sailboat,
                label: 'Helm',
                active: active == TideTab.helm,
                onTap: () => _go(context, TideTab.helm),
              ),
              _NavItem(
                icon: AppAssets.wavesNav,
                label: 'Haven',
                active: active == TideTab.breathe,
                onTap: () => _go(context, TideTab.breathe),
              ),
              _NavItem(
                icon: AppAssets.pen,
                label: 'Log',
                active: active == TideTab.log,
                onTap: () => _go(context, TideTab.log),
              ),
              _NavItem(
                icon: AppAssets.users,
                label: 'Crew',
                active: active == TideTab.crew,
                onTap: () => _go(context, TideTab.crew),
              ),
              _NavItem(
                icon: AppAssets.chartLine,
                label: 'Insights',
                active: active == TideTab.insights,
                onTap: () => _go(context, TideTab.insights),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final labelStyle = active
        ? AppTextStyles.navLabel.copyWith(
            color: AppColors.seafoam,
            fontWeight: FontWeight.w600,
          )
        : AppTextStyles.navLabel;
    final colorFilter = active
        ? const ColorFilter.mode(AppColors.seafoam, BlendMode.srcIn)
        : const ColorFilter.mode(AppColors.muted, BlendMode.srcIn);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              width: 24,
              height: 24,
              colorFilter: colorFilter,
            ),
            const SizedBox(height: 4),
            Text(label, style: labelStyle),
          ],
        ),
      ),
    );
  }
}
