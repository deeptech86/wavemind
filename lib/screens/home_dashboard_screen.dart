import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/models/voyage_status.dart';
import '../data/wellness_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/auth_form.dart';
import '../widgets/tide_bottom_nav.dart';
import 'community_connect_screen.dart';
import 'haven_screen.dart';
import 'journal_entry_screen.dart';
import 'profile_screen.dart';
import 'weekly_insights_screen.dart';

/// Days left in the current weekly challenge window. Challenges run
/// Monday–Sunday, so this counts down to the following Monday.
int daysRemainingInChallengeWeek([DateTime? now]) {
  final today = now ?? DateTime.now();
  return DateTime.sunday - today.weekday;
}

/// Main app dashboard shown after onboarding — the "Helm" (Stitch
/// "helm_dashboard" redesign).
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key, WellnessRepository? repository})
    : _repository = repository;

  /// Optional injection point for tests; defaults to the shared on-device repo.
  final WellnessRepository? _repository;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late final WellnessRepository _repo =
      widget._repository ?? WellnessRepository();

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

  void _open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TideBottomNav(active: TideTab.helm),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(repository: _repo),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeaderboardScoreBanner(
                        totalKnots: _summary.totalKnots,
                        rank: currentFleetRank(_summary.totalKnots),
                        daysToGo: daysRemainingInChallengeWeek(),
                        onTap: () => _open(
                          context,
                          const CommunityConnectScreen(
                            initialTab: CrewTab.fleetSpirit,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        'Mental Helm Controls',
                        trailing: 'Customize',
                      ),
                      const SizedBox(height: 16),
                      _FeatureGrid(
                        onHaven: () => _open(context, const HavenScreen()),
                        onJournal: () =>
                            _open(context, const JournalEntryScreen()),
                        onCrew: () =>
                            _open(context, const CommunityConnectScreen()),
                        onReflect: () =>
                            _open(context, const WeeklyInsightsScreen()),
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
// Header
// ---------------------------------------------------------------------------

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.repository});

  final WellnessRepository repository;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decorative full-bleed wave strip.
        SizedBox(
          height: 16,
          width: double.infinity,
          child: SvgPicture.asset(
            AppAssets.decoWaves,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UserProfileBar(),
              const SizedBox(height: 16),
              _VoyageBanner(repository: repository),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserProfileBar extends StatelessWidget {
  const _UserProfileBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ahoy, First Mate', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'Marcus Thorne',
                style: AppTextStyles.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
          ),
          child: Semantics(
            button: true,
            label: 'Open crew profile',
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(AppAssets.avatar, fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Helm "Voyage Details" card.
///
/// First run (no saved status) always opens on the ask-form: Docked or
/// Voyage, and if Voyage, From/To/Days Remaining. Once saved, the form
/// collapses to a one-line summary + Edit button; tapping Edit re-opens the
/// form pre-filled with the current values. A voyage's countdown only ever
/// goes down from the days-remaining value entered at save time — it is not
/// derived from a start date — and auto-reads as Docked once it hits 0.
class _VoyageBanner extends StatefulWidget {
  const _VoyageBanner({required this.repository});

  final WellnessRepository repository;

  @override
  State<_VoyageBanner> createState() => _VoyageBannerState();
}

class _VoyageBannerState extends State<_VoyageBanner> {
  bool _loaded = false;
  bool _editing = false;
  VoyageStatus? _status;

  VoyageState _formState = VoyageState.docked;
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    // Keep the Save button's enabled state in sync as the sailor types.
    for (final c in [_originCtrl, _destinationCtrl, _daysCtrl]) {
      c.addListener(_onFormFieldChanged);
    }
  }

  void _onFormFieldChanged() => setState(() {});

  @override
  void dispose() {
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final status = await widget.repository.voyageStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loaded = true;
      _editing = status == null; // first run: go straight to the ask-form.
    });
  }

  void _startEdit() {
    final current = _status;
    final effective = current?.effectiveState();
    setState(() {
      _formState = effective ?? VoyageState.docked;
      _originCtrl.text = current?.origin ?? '';
      _destinationCtrl.text = current?.destination ?? '';
      final remaining = current?.daysRemaining();
      _daysCtrl.text = remaining != null && remaining > 0
          ? '$remaining'
          : '';
      _editing = true;
    });
  }

  bool get _canSave {
    if (_formState == VoyageState.docked) return true;
    final days = int.tryParse(_daysCtrl.text.trim());
    return _originCtrl.text.trim().isNotEmpty &&
        _destinationCtrl.text.trim().isNotEmpty &&
        days != null &&
        days > 0;
  }

  Future<void> _save() async {
    final isVoyage = _formState == VoyageState.voyage;
    final status = VoyageStatus(
      state: _formState,
      origin: isVoyage ? _originCtrl.text.trim() : null,
      destination: isVoyage ? _destinationCtrl.text.trim() : null,
      totalDays: isVoyage ? int.tryParse(_daysCtrl.text.trim()) : null,
      anchoredAt: isVoyage ? DateTime.now() : null,
    );
    await widget.repository.saveVoyageStatus(status);
    if (!mounted) return;
    setState(() {
      _status = status;
      _editing = false;
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
          borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      ),
      child: _editing ? _buildForm() : _buildSummary(),
    );
  }

  Widget _buildSummary() {
    final status = _status!;
    final effective = status.effectiveState();
    final isVoyage = effective == VoyageState.voyage;
    final remaining = status.daysRemaining() ?? 0;
    return Row(
      children: [
        SvgPicture.asset(AppAssets.compass, width: 24, height: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVoyage
                    ? '$remaining ${remaining == 1 ? 'Day' : 'Days'} Remaining'
                    : 'Docked',
                style: AppTextStyles.labelStrong,
              ),
              const SizedBox(height: 2),
              Text(
                isVoyage
                    ? 'Voyage: ${status.origin} to ${status.destination}'
                    : 'No active voyage',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.seafoamFaint,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            onTap: _startEdit,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                'Edit',
                style: TextStyle(
                  color: AppColors.seafoam,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(AppAssets.compass, width: 20, height: 20),
            const SizedBox(width: 10),
            Text('Voyage Details', style: AppTextStyles.labelStrong),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _VoyageStateOption(
                label: 'Docked',
                selected: _formState == VoyageState.docked,
                onTap: () => setState(() => _formState = VoyageState.docked),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VoyageStateOption(
                label: 'Voyage',
                selected: _formState == VoyageState.voyage,
                onTap: () => setState(() => _formState = VoyageState.voyage),
              ),
            ),
          ],
        ),
        if (_formState == VoyageState.voyage) ...[
          const SizedBox(height: 12),
          AuthTextField(
            label: 'From',
            controller: _originCtrl,
            hint: 'e.g. Yokohama',
            textCapitalizationWords: true,
            fillColor: AppColors.glassFill,
          ),
          const SizedBox(height: 10),
          AuthTextField(
            label: 'To',
            controller: _destinationCtrl,
            hint: 'e.g. Valparaiso',
            textCapitalizationWords: true,
            fillColor: AppColors.glassFill,
          ),
          const SizedBox(height: 10),
          AuthTextField(
            label: 'Days Remaining',
            controller: _daysCtrl,
            hint: 'e.g. 21',
            keyboardType: TextInputType.number,
            fillColor: AppColors.glassFill,
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: AuthPrimaryButton(
            label: 'Save',
            busy: false,
            onTap: _canSave ? _save : null,
          ),
        ),
      ],
    );
  }
}

/// One Docked/Voyage choice chip in the Voyage Details form.
class _VoyageStateOption extends StatelessWidget {
  const _VoyageStateOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.seafoamFaint : AppColors.glassFill,
      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? AppColors.seafoam : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: selected ? AppColors.seafoam : AppColors.muted,
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
// Fleet Standing leaderboard-score banner
// ---------------------------------------------------------------------------

/// Live Fleet Knots score card. Reuses the former story banner's visual
/// language (card surface, icon-chip + text + trailing circle) but surfaces the
/// user's real Fleet Knots total and deep-links straight into the Fleet Spirit
/// leaderboard tab on Crew.
class _LeaderboardScoreBanner extends StatelessWidget {
  const _LeaderboardScoreBanner({
    required this.totalKnots,
    required this.rank,
    required this.daysToGo,
    required this.onTap,
  });

  final int totalKnots;
  final int rank;

  /// Days left in the current weekly challenge window (Monday–Sunday).
  final int daysToGo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealFaint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                  border: Border.all(color: AppColors.tealBorder),
                ),
                // Matches the Fleet Spirit tab icon in community_connect_screen.
                child: const Icon(
                  Icons.military_tech,
                  size: 24,
                  color: AppColors.sand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VOYAGE TO VICTORY',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.sand,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalKnots Fleet Knots',
                      style: AppTextStyles.cardTitleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rank #$rank • $daysToGo ${daysToGo == 1 ? 'day' : 'days'} to go',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.seafoam,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.seafoam,
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.onAccent,
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
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.cream),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Text(
            trailing!,
            style: AppTextStyles.caption.copyWith(color: AppColors.seafoam),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feature grid
// ---------------------------------------------------------------------------

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.onHaven,
    required this.onJournal,
    required this.onCrew,
    required this.onReflect,
  });

  final VoidCallback onHaven;
  final VoidCallback onJournal;
  final VoidCallback onCrew;
  final VoidCallback onReflect;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 12);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.waves,
                  iconColor: AppColors.seafoam,
                  title: 'Haven',
                  subtitle: 'Calm Drills, Stories & Tidal Breath',
                  badge: '3 Ready',
                  onTap: onHaven,
                ),
              ),
              gap,
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.bookOpenText,
                  iconColor: AppColors.teal,
                  title: 'Journal & Log',
                  subtitle: 'Shift debrief & private thoughts',
                  onTap: onJournal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.anchor,
                  iconColor: AppColors.seafoam,
                  title: 'Crew & Fleet',
                  subtitle: 'Anchor pool & spirit leaderboard',
                  onTap: onCrew,
                ),
              ),
              gap,
              Expanded(
                child: _FeatureTile(
                  icon: AppAssets.chartLine,
                  iconColor: AppColors.sand,
                  title: 'Reflect',
                  subtitle: 'Weekly swell horizon & trends',
                  onTap: onReflect,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final String icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        icon,
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.seafoamFaint,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(color: AppColors.seafoamBorder),
                      ),
                      child: Text(
                        badge!,
                        style: AppTextStyles.badge.copyWith(fontSize: 9),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: AppTextStyles.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.caption, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// Off-Watch Mind Games now lives in Haven (lib/screens/haven_screen.dart),
// between Sleep Lore and Ambient Cabin Soundscapes.
