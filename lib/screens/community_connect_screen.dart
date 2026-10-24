import 'package:flutter/material.dart';

import '../data/health_data_service.dart';
import '../data/models/voyage_status.dart';
import '../data/wellness_repository.dart';
import '../data/wellness_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/tide_bottom_nav.dart';
import 'anonymous_chat_screen.dart';

/// The user's live rank among the fixed mock competitor roster, derived from
/// their real Fleet Knots total. Exposed (rather than the roster itself) so
/// other screens — e.g. Helm's Fleet Standing banner — can show the same rank
/// without duplicating or exposing the mock leaderboard data.
int currentFleetRank(int totalKnots) =>
    WellnessStats.rankAmong(totalKnots, _Leaderboard.competitorKnots);

/// "Crew" screen (Stitch "crew_fleet_leaderboard" redesign).
///
/// A two-part destination behind a segmented control:
///   * **Anchor Pool** — the original community content (anonymized crew swell,
///     cast-a-float-bottle, gratitude notes), unchanged, still linking to the
///     anonymous chat.
///   * **Fleet Spirit** — a new voyage-milestone / contribution / leaderboard
///     view ranked by "knots". Static data for Stage 1.
///
/// Fleet Spirit is the default — the individual weekly-challenge competition
/// is the primary reason to open Crew now — but a caller can still request
/// Anchor Pool explicitly via [initialTab].
class CommunityConnectScreen extends StatefulWidget {
  const CommunityConnectScreen({
    super.key,
    WellnessRepository? repository,
    HealthDataService? healthService,
    this.initialTab = CrewTab.fleetSpirit,
  }) : _repository = repository,
       _healthService = healthService;

  final WellnessRepository? _repository;

  /// Optional injection point for tests. In production the health-sync button
  /// builds its own [HealthDataService]; nothing it reads is ever persisted.
  final HealthDataService? _healthService;

  /// The tab to show first. Defaults to [CrewTab.fleetSpirit].
  final CrewTab initialTab;

  @override
  State<CommunityConnectScreen> createState() => _CommunityConnectScreenState();
}

/// The two Crew destinations behind the segmented control. Public so callers
/// can request an initial tab via [CommunityConnectScreen.initialTab].
enum CrewTab { anchorPool, fleetSpirit }

class _CommunityConnectScreenState extends State<CommunityConnectScreen> {
  late final WellnessRepository _repo =
      widget._repository ?? WellnessRepository();
  late CrewTab _tab = widget.initialTab;
  ContributionSummary _summary = ContributionSummary.empty;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await _repo.contributionSummary();
    if (!mounted) return;
    setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TideBottomNav(active: TideTab.crew),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Crew', style: AppTextStyles.headerTitle),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SegmentedControl(
                        active: _tab,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                      const SizedBox(height: 20),
                      if (_tab == CrewTab.anchorPool)
                        _AnchorPoolView(
                          onCast: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AnonymousChatScreen(),
                            ),
                          ),
                        )
                      else
                        _FleetSpiritView(
                          summary: _summary,
                          repository: _repo,
                          healthService: widget._healthService,
                          onSynced: _loadSummary,
                        ),
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

// ---------------------------------------------------------------------------
// Segmented control
// ---------------------------------------------------------------------------

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.active, required this.onChanged});

  final CrewTab active;
  final ValueChanged<CrewTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              icon: Icons.military_tech,
              label: 'Fleet Spirit',
              selected: active == CrewTab.fleetSpirit,
              onTap: () => onChanged(CrewTab.fleetSpirit),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              icon: Icons.waves,
              label: 'Anchor Pool',
              selected: active == CrewTab.anchorPool,
              onTap: () => onChanged(CrewTab.anchorPool),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.seafoam : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.onAccent : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: selected ? AppColors.onAccent : AppColors.muted,
                  ),
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

// ===========================================================================
// Anchor Pool view (existing content, preserved)
// ===========================================================================

class _AnchorPoolView extends StatelessWidget {
  const _AnchorPoolView({required this.onCast});

  final VoidCallback onCast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CrewMoodDashboard(),
        const SizedBox(height: 20),
        _EncourageBox(onCast: onCast),
        const SizedBox(height: 20),
        const _GratitudeWall(),
      ],
    );
  }
}

class _CrewMoodDashboard extends StatelessWidget {
  const _CrewMoodDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Anonymized Crew Swell',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.seafoamFaint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('STEADY VIBE', style: AppTextStyles.badge),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.glassFillFaint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.teal, width: 4),
                ),
                child: Text('82%', style: AppTextStyles.headerTitle),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calm or Steady Winds',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.cream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aggregated state across all 18 watch members currently '
                      'logged on.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EncourageBox extends StatelessWidget {
  const _EncourageBox({required this.onCast});

  final VoidCallback onCast;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 10),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cast a Float Bottle (Encouragement)',
            style: AppTextStyles.cardTitleSmall,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.overlayDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Type a silent supportive message to be cast anonymously into the '
              'mess deck display...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.tealTint,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onCast,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                child: Text(
                  'Cast to Fleet',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.teal,
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

class _GratitudeWall extends StatelessWidget {
  const _GratitudeWall();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIGGING GRATITUDE NOTES',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.cream),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _GratitudeNote(
                text:
                    "“Grateful for the chef's fresh sourdough this morning. "
                    'Little things make the watch better.”',
                author: 'Anonymous Deckhand',
              ),
              SizedBox(width: 10),
              _GratitudeNote(
                text:
                    '“Clean water line finally fixed. Good hot shower was '
                    'legendary.”',
                author: 'Anonymous Engineer',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GratitudeNote extends StatelessWidget {
  const _GratitudeNote({required this.text, required this.author});

  final String text;
  final String author;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.white,
                height: 1.4,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            author,
            style: AppTextStyles.badge.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Fleet Spirit view (new — static Stage 1 data)
// ===========================================================================

class _FleetSpiritView extends StatelessWidget {
  const _FleetSpiritView({
    required this.summary,
    required this.repository,
    required this.onSynced,
    this.healthService,
  });

  final ContributionSummary summary;
  final WellnessRepository repository;
  final HealthDataService? healthService;

  /// Called after a successful health sync so the parent reloads the summary.
  final Future<void> Function() onSynced;

  @override
  Widget build(BuildContext context) {
    final rank = currentFleetRank(summary.totalKnots);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VoyageMilestoneCard(repository: repository),
        const SizedBox(height: 20),
        _ContributionCard(
          summary: summary,
          rank: rank,
          repository: repository,
          healthService: healthService,
          onSynced: onSynced,
        ),
        const SizedBox(height: 24),
        _LeaderboardSection(summary: summary),
        const SizedBox(height: 20),
        const _KnotsInfoDeck(),
      ],
    );
  }
}

/// Mirrors the same on-device [VoyageStatus] the Helm "Voyage Details" card
/// reads/writes — the route headline and day count reflect whatever was last
/// saved there. The rest of the card (leg badge, watch/swell stats, progress
/// bar, NM traveled) has no real data source yet and stays illustrative, but
/// only renders when an actual voyage is active — it has nothing to show
/// while docked.
class _VoyageMilestoneCard extends StatefulWidget {
  const _VoyageMilestoneCard({required this.repository});

  final WellnessRepository repository;

  @override
  State<_VoyageMilestoneCard> createState() => _VoyageMilestoneCardState();
}

class _VoyageMilestoneCardState extends State<_VoyageMilestoneCard> {
  bool _loaded = false;
  VoyageStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await widget.repository.voyageStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Container(
        width: double.infinity,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
      );
    }

    final status = _status;
    final isVoyage =
        status != null && status.effectiveState() == VoyageState.voyage;

    if (!isVoyage) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VOYAGE MILESTONE', style: AppTextStyles.badge),
            const SizedBox(height: 4),
            Text('Docked', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Set sail from the Helm to track your voyage here.',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    final remaining = status.daysRemaining() ?? 0;
    final totalDays = status.totalDays ?? 0;
    // Elapsed days since the countdown was saved, as a fraction of the
    // total days entered then — e.g. 20 days saved, 10 left today = 50%.
    final percentComplete = totalDays > 0
        ? ((totalDays - remaining) / totalDays).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VOYAGE MILESTONE', style: AppTextStyles.badge),
                    const SizedBox(height: 4),
                    Text(
                      '${status.origin} to ${status.destination}',
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 14,
                      color: AppColors.sand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Leg 2',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.sand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Watch Solidarity Target: Maintain calm wake across collective '
            'shifts.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Port Watch',
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  '${(percentComplete * 100).round()}% Completed',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.seafoam,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  'Starboard',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: percentComplete,
              minHeight: 8,
              backgroundColor: AppColors.deepNavy,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.seafoam),
            ),
          ),
          const SizedBox(height: 8),
          // NM traveled/to go were static placeholder distances with no real
          // data source (no route-progress model exists), so they're gone —
          // only the real, saved days-remaining count is shown.
          Text(
            '$remaining ${remaining == 1 ? 'Day' : 'Days'} Remaining',
            style: AppTextStyles.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({
    required this.summary,
    required this.rank,
    required this.repository,
    required this.onSynced,
    this.healthService,
  });

  final ContributionSummary summary;
  final int rank;
  final WellnessRepository repository;
  final HealthDataService? healthService;
  final Future<void> Function() onSynced;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSurface, AppColors.navyBlue],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InitialsAvatar(
                initials: 'MT',
                color: AppColors.teal,
                rank: '#$rank',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR CONTRIBUTION', style: AppTextStyles.badge),
                    const SizedBox(height: 2),
                    Text(
                      '1st Mate Marcus Thorne',
                      style: AppTextStyles.cardTitleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('MV Pacific Osprey', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${summary.totalKnots}',
                    style: AppTextStyles.headerTitle.copyWith(
                      color: AppColors.seafoam,
                    ),
                  ),
                  Text('FLEET KNOTS', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _KnotBadge(
                  icon: Icons.verified_outlined,
                  label: 'Steady Helm (${summary.breathStreakDays}d Streak)',
                  color: AppColors.seafoam,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KnotBadge(
                  icon: Icons.military_tech,
                  label: 'Rank #$rank',
                  color: AppColors.cream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _KnotBadge(
                  icon: Icons.menu_book_outlined,
                  label: '${summary.seaLogsFiled} Sea Logs Filed',
                  color: AppColors.sand,
                ),
              ),
              const SizedBox(width: 8),
              _HealthSyncButton(
                repository: repository,
                healthService: healthService,
                onSynced: onSynced,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Phase of the tap-triggered manual health sync. Mirrors the states
/// `_WatchHealthCard` in weekly_insights_screen.dart already solves, collapsed
/// to what a single button needs:
///   * [unsupported] — no health store on this platform; the button hides.
///   * [idle] — ready to sync.
///   * [syncing] — a sync is in flight (availability/permission/read/persist).
enum _SyncPhase { unsupported, idle, syncing }

/// A compact "Sync Watch Data" pill inside the contribution card. On tap it
/// live-reads today's steps + sleep from the phone health store, converts them
/// to Fleet Knots points, and — if the total is positive — persists a single
/// one-off ledger entry then refreshes the card. Raw health values never leave
/// ephemeral memory; only the computed points are persisted.
///
/// It handles the same availability/permission lifecycle as the Watch Vitals
/// card (unsupported -> hidden; Health Connect missing -> prompt to install;
/// not yet authorized -> request; denied -> retry messaging), surfaced as
/// SnackBars rather than a full card body since this is a single button.
class _HealthSyncButton extends StatefulWidget {
  const _HealthSyncButton({
    required this.repository,
    required this.onSynced,
    this.healthService,
  });

  final WellnessRepository repository;
  final HealthDataService? healthService;
  final Future<void> Function() onSynced;

  @override
  State<_HealthSyncButton> createState() => _HealthSyncButtonState();
}

class _HealthSyncButtonState extends State<_HealthSyncButton> {
  late final HealthDataService _service =
      widget.healthService ?? HealthDataService();

  _SyncPhase _phase = _SyncPhase.idle;

  @override
  void initState() {
    super.initState();
    _probeAvailability();
  }

  /// Decide up-front whether this platform has a health store at all; if not,
  /// the button hides itself (matching the Watch Vitals card's unsupported
  /// behavior) rather than offering a sync that can never work.
  Future<void> _probeAvailability() async {
    try {
      final availability = await _service.availability();
      if (!mounted) return;
      if (availability == HealthAvailability.unsupported) {
        setState(() => _phase = _SyncPhase.unsupported);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _SyncPhase.unsupported);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sync() async {
    if (_phase == _SyncPhase.syncing) return;
    setState(() => _phase = _SyncPhase.syncing);
    try {
      // 1. Re-check the store is reachable (and installed on Android).
      final availability = await _service.availability();
      if (!mounted) return;
      switch (availability) {
        case HealthAvailability.unsupported:
          setState(() => _phase = _SyncPhase.unsupported);
          return;
        case HealthAvailability.needsInstall:
          _notify(
            'Health Connect is required to sync on Android. Opening the '
            'Play Store…',
          );
          await _service.installHealthStore();
          if (mounted) setState(() => _phase = _SyncPhase.idle);
          return;
        case HealthAvailability.available:
          break;
      }

      // 2. Ensure read permission, requesting it if we don't already have it.
      final granted = await _service.hasPermissions();
      if (!mounted) return;
      if (granted != true) {
        final ok = await _service.requestPermissions();
        if (!mounted) return;
        if (!ok) {
          _notify(
            'Health access was declined. Grant read access to steps and '
            'sleep, then tap Sync again.',
          );
          setState(() => _phase = _SyncPhase.idle);
          return;
        }
      }

      // 3. Live-read + convert to points (null metrics count as 0).
      final snapshot = await _service.readToday();
      if (!mounted) return;
      final points = HealthDataService.pointsForSync(snapshot);

      // 4. Persist only a positive, meaningful amount; refresh + confirm.
      if (points > 0) {
        await widget.repository.recordHealthSync(knots: points);
        await widget.onSynced();
        _notify("Synced — +$points Fleet Knots from today's activity.");
      } else {
        _notify('No health data to sync yet today.');
      }
    } catch (_) {
      // Degrade gracefully: a denied permission or unreachable store must
      // never throw into the UI.
      _notify('Could not sync health data right now. Please try again.');
    } finally {
      if (mounted && _phase == _SyncPhase.syncing) {
        setState(() => _phase = _SyncPhase.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // No health store on this platform: offer nothing.
    if (_phase == _SyncPhase.unsupported) return const SizedBox.shrink();

    final syncing = _phase == _SyncPhase.syncing;
    return Material(
      color: AppColors.seafoamFaint,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        onTap: syncing ? null : _sync,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncing)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.seafoam,
                  ),
                )
              else
                const Icon(Icons.sync, size: 16, color: AppColors.seafoam),
              const SizedBox(width: 8),
              Text(
                syncing ? 'Syncing…' : 'Sync Watch Data',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.seafoam,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnotBadge extends StatelessWidget {
  const _KnotBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single leaderboard competitor. The four non-user crew are fixed mock data
/// (there is no multi-user backend); only the "You" row is backed by real
/// on-device stats.
class _LeaderEntry {
  const _LeaderEntry({
    required this.initials,
    required this.color,
    required this.name,
    required this.note,
    required this.knots,
    this.tag,
    this.isUser = false,
  });

  final String initials;
  final Color color;
  final String name;
  final String note;
  final int knots;
  final String? tag;
  final bool isUser;
}

/// Static competitor roster (and their fixed knot totals) used both to render
/// the other rows and to rank the real user against them.
abstract final class _Leaderboard {
  static const List<_LeaderEntry> competitors = [
    _LeaderEntry(
      initials: 'LS',
      color: AppColors.seafoam,
      name: 'Bosun Liam S.',
      note: '14-day steady swell streak',
      knots: 850,
      tag: 'Fleet Beacon',
    ),
    _LeaderEntry(
      initials: 'DK',
      color: AppColors.sand,
      name: 'Chief Eng. Dave K.',
      note: '9 sound-down cabin rests logged',
      knots: 780,
    ),
    _LeaderEntry(
      initials: 'ER',
      color: AppColors.teal,
      name: 'Deckhand Elena R.',
      note: '10 tidal breath resets',
      knots: 650,
    ),
    _LeaderEntry(
      initials: 'AM',
      color: AppColors.sand,
      name: 'Cadet Aris M.',
      note: 'First Voyage Star • 6 logs true',
      knots: 590,
    ),
  ];

  static List<int> get competitorKnots =>
      [for (final c in competitors) c.knots];
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.summary});

  final ContributionSummary summary;

  @override
  Widget build(BuildContext context) {
    // The top 4 competitors always hold rows 1-4 in fixed order; the real
    // user is always appended as the 5th row, labeled with their true
    // individual rank rather than their position in this list.
    final you = _LeaderEntry(
      initials: 'MT',
      color: AppColors.teal,
      name: 'Marcus Thorne (You)',
      note: '${summary.seaLogsFiled} sea logs filed',
      knots: summary.totalKnots,
      isUser: true,
    );
    final entries = [..._Leaderboard.competitors, you];
    final ranks = [
      for (var i = 0; i < _Leaderboard.competitors.length; i++) i + 1,
      currentFleetRank(summary.totalKnots),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet Solidarity Log',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Celebrating restorative actions & crew presence',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.glassFillFaint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Voyage',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.seafoam,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('7 Days', style: AppTextStyles.caption),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _LeaderRow(
            rank: ranks[i],
            initials: entries[i].initials,
            color: entries[i].color,
            name: entries[i].name,
            note: entries[i].note,
            knots: '${entries[i].knots}',
            tag: entries[i].tag,
            highlighted: entries[i].isUser,
          ),
        ],
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.initials,
    required this.color,
    required this.name,
    required this.note,
    required this.knots,
    this.tag,
    this.highlighted = false,
  });

  final int rank;
  final String initials;
  final Color color;
  final String name;
  final String note;
  final String knots;
  final String? tag;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.seafoamFaint : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: highlighted
            ? Border.all(color: AppColors.seafoamBorder)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: rank == 1
                ? const Icon(
                    Icons.workspace_premium,
                    size: 22,
                    color: AppColors.sand,
                  )
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.statValue.copyWith(
                      color: highlighted ? AppColors.seafoam : AppColors.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          _InitialsAvatar(initials: initials, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: highlighted ? AppColors.seafoam : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.seafoamFaint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag!,
                          style: AppTextStyles.badge.copyWith(fontSize: 9),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                knots,
                style: AppTextStyles.statValue.copyWith(
                  color: highlighted ? AppColors.seafoam : AppColors.white,
                ),
              ),
              Text('knots', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    required this.color,
    this.size = 48,
    this.rank,
  });

  final String initials;
  final Color color;
  final double size;
  final String? rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Text(
              initials,
              style: AppTextStyles.bodyStrong.copyWith(color: color),
            ),
          ),
          if (rank != null)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.seafoam,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(color: AppColors.deepNavy, width: 1.5),
                ),
                child: Text(
                  rank!,
                  style: AppTextStyles.badge.copyWith(
                    color: AppColors.onAccent,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KnotsInfoDeck extends StatelessWidget {
  const _KnotsInfoDeck();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.seafoamFaint,
              borderRadius: BorderRadius.circular(AppTheme.radiusTile),
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 22,
              color: AppColors.seafoam,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How Fleet Knots are Earned',
                  style: AppTextStyles.cardTitleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Knots measure supportive presence, not competition. Gain '
                  'knots by checking your daily swell (+30), casting float '
                  'bottles (+40), and completing shift-change breath routines '
                  '(+50).',
                  style: AppTextStyles.caption.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
