import 'package:flutter/material.dart';

import '../data/health_data_service.dart';
import '../data/leaderboard_service.dart';
import '../data/models/leaderboard_entry.dart';
import '../data/models/voyage_status.dart';
import '../data/wellness_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/tide_bottom_nav.dart';
import 'anonymous_chat_screen.dart';

/// "Crew" screen (Stitch "crew_fleet_leaderboard" redesign).
///
/// A two-part destination behind a segmented control:
///   * **Anchor Pool** — the original community content (anonymized crew swell,
///     cast-a-float-bottle, gratitude notes), unchanged, still linking to the
///     anonymous chat.
///   * **Fleet Spirit** — a voyage-milestone / contribution / leaderboard view
///     ranked by real Fleet Knots, synced to the backend via
///     [LeaderboardService] — no fake competitor data.
///
/// Fleet Spirit is the default — the individual weekly-challenge competition
/// is the primary reason to open Crew now — but a caller can still request
/// Anchor Pool explicitly via [initialTab].
class CommunityConnectScreen extends StatefulWidget {
  const CommunityConnectScreen({
    super.key,
    WellnessRepository? repository,
    HealthDataService? healthService,
    LeaderboardService? leaderboardService,
    this.initialTab = CrewTab.fleetSpirit,
  }) : _repository = repository,
       _healthService = healthService,
       _leaderboardService = leaderboardService;

  final WellnessRepository? _repository;

  /// Optional injection point for tests. In production the health-sync button
  /// builds its own [HealthDataService]; nothing it reads is ever persisted.
  final HealthDataService? _healthService;

  /// Optional injection point for tests.
  final LeaderboardService? _leaderboardService;

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
  late final LeaderboardService _leaderboardService =
      widget._leaderboardService ?? LeaderboardService();
  late CrewTab _tab = widget.initialTab;
  ContributionSummary _summary = ContributionSummary.empty;

  /// Null while loading or if the sync failed — callers must never fall back
  /// to fake rows, only show a graceful "unavailable" state.
  List<LeaderboardEntry>? _leaderboard;
  bool _leaderboardLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await _repo.contributionSummary();
    if (!mounted) return;
    setState(() => _summary = summary);
    await _syncLeaderboard(summary.totalKnots);
  }

  Future<void> _syncLeaderboard(int totalKnots) async {
    if (!mounted) return;
    setState(() => _leaderboardLoading = true);
    List<LeaderboardEntry>? result;
    try {
      result = await _leaderboardService.sync(totalKnots);
    } catch (_) {
      // Network/server failure: leave result null so the UI shows its
      // "unavailable" state rather than any fabricated data.
      result = null;
    }
    if (!mounted) return;
    setState(() {
      _leaderboard = result;
      _leaderboardLoading = false;
    });
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
                          leaderboard: _leaderboard,
                          leaderboardLoading: _leaderboardLoading,
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
// Fleet Spirit view — real, backend-synced leaderboard (no mock competitors)
// ===========================================================================

class _FleetSpiritView extends StatelessWidget {
  const _FleetSpiritView({
    required this.summary,
    required this.repository,
    required this.onSynced,
    required this.leaderboard,
    required this.leaderboardLoading,
    this.healthService,
  });

  final ContributionSummary summary;
  final WellnessRepository repository;
  final HealthDataService? healthService;

  /// Null while loading or if the last sync failed.
  final List<LeaderboardEntry>? leaderboard;
  final bool leaderboardLoading;

  /// Called after a successful health sync so the parent reloads the summary
  /// (and re-syncs the leaderboard with the new total).
  final Future<void> Function() onSynced;

  @override
  Widget build(BuildContext context) {
    int? myRank;
    for (final entry in leaderboard ?? const <LeaderboardEntry>[]) {
      if (entry.isMe) {
        myRank = entry.rank;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VoyageMilestoneCard(repository: repository),
        const SizedBox(height: 20),
        _ContributionCard(
          summary: summary,
          rank: myRank,
          repository: repository,
          healthService: healthService,
          onSynced: onSynced,
        ),
        const SizedBox(height: 24),
        _LeaderboardSection(
          entries: leaderboard,
          loading: leaderboardLoading,
        ),
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
          Text('VOYAGE MILESTONE', style: AppTextStyles.badge),
          const SizedBox(height: 4),
          Text(
            '${status.origin} to ${status.destination}',
            style: AppTextStyles.titleMedium,
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

  /// Null while the leaderboard sync hasn't resolved yet (loading or failed).
  final int? rank;
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
                  label: rank != null ? 'Rank #$rank' : 'Rank —',
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

/// Derives display initials from a real account name — "Marcus Thorne" -> MT,
/// a single-word name -> its first letter.
String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.entries, required this.loading});

  /// Null while loading or if the last backend sync failed — never fake rows.
  final List<LeaderboardEntry>? entries;
  final bool loading;

  @override
  Widget build(BuildContext context) {
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
                  Text('Leadership Board', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Ranked by real Fleet Knots across the crew',
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
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.seafoam,
                ),
              ),
            ),
          )
        else if (entries == null || entries!.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.glassFillFaint,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppColors.glassBorderSoft),
            ),
            child: Text(
              'Leadership Board is unavailable right now — check the '
              'backend connection and reopen Crew.',
              style: AppTextStyles.bodySmall,
            ),
          )
        else
          for (var i = 0; i < entries!.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _LeaderRow(
              rank: entries![i].rank,
              initials: _initialsFor(entries![i].name),
              color: entries![i].isMe ? AppColors.teal : AppColors.sand,
              name: entries![i].isMe
                  ? '${entries![i].name} (You)'
                  : entries![i].name,
              note: entries![i].fleetName,
              knots: '${entries![i].totalPoints}',
              highlighted: entries![i].isMe,
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
    this.highlighted = false,
  });

  final int rank;
  final String initials;
  final Color color;
  final String name;

  /// Fleet name, if the account has one — null/empty shows no second line.
  final String? note;
  final String knots;
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
                Text(
                  name,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: highlighted ? AppColors.seafoam : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
