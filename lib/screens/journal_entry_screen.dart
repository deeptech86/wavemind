import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../data/models/journal_entry.dart';
import '../data/wellness_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/back_header.dart';
import '../widgets/tide_bottom_nav.dart';
import 'mood_check_in_screen.dart';

/// "Captain's Private Log" journal entry (Figma node 3:235 "journal-entry").
///
/// Stage 4: the writing slate is now a real text field, "Save" persists the
/// entry on-device (awarding Fleet Knots), and previously filed logs are listed
/// below.
class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key, WellnessRepository? repository})
    : _repository = repository;

  final WellnessRepository? _repository;

  /// The daily seaprompt persisted alongside each entry written today.
  static const String dailyPrompt =
      'What sound of the rigging or water brought you peace today?';

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  late final WellnessRepository _repo =
      widget._repository ?? WellnessRepository();
  final TextEditingController _controller = TextEditingController();

  List<JournalEntry> _pastEntries = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _repo.journalEntries();
    if (!mounted) return;
    setState(() {
      _pastEntries = entries;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a few words before securing the log.')),
      );
      return;
    }
    setState(() => _saving = true);
    await _repo.saveJournalEntry(
      body: text,
      prompt: JournalEntryScreen.dailyPrompt,
    );
    if (!mounted) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    await _loadEntries();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log secured in your ship vault. +40 knots')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const TideBottomNav(active: TideTab.log),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackHeader(
                title: "Captain's Private Log",
                trailing: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.seafoam,
                        ),
                      )
                    : InkWell(
                        onTap: _save,
                        child: Text(
                          'Save',
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: AppColors.seafoam,
                          ),
                        ),
                      ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _CoordinatesStamp(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoodLauncher(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MoodCheckInScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _PromptCard(),
                      const SizedBox(height: 20),
                      _WritingSlate(controller: _controller),
                      const SizedBox(height: 20),
                      const _SlateTools(),
                      const SizedBox(height: 28),
                      _PastEntries(loading: _loading, entries: _pastEntries),
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

class _CoordinatesStamp extends StatelessWidget {
  const _CoordinatesStamp();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(AppAssets.mapPin, width: 16, height: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Coord: 32°14'N, 64°49'W · Wind Force 4",
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.cream),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Compact launcher for the mood check-in flow. The Helm redesign dropped the
/// standalone "Log Swell" card, so daily emotional-swell logging now lives here
/// inside the logbook where it belongs conceptually.
class _MoodLauncher extends StatelessWidget {
  const _MoodLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.teal,
      borderRadius: BorderRadius.circular(AppTheme.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SvgPicture.asset(
                AppAssets.smilePlus,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Emotional Swell',
                      style: AppTextStyles.cardTitleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Record how the sea within you feels today',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.tealTint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFillFaint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(AppAssets.lightbulbOff, width: 20, height: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY SEAPROMPT', style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  JournalEntryScreen.dailyPrompt,
                  style: AppTextStyles.promptMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WritingSlate extends StatelessWidget {
  const _WritingSlate({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: TextField(
        controller: controller,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        cursorColor: AppColors.seafoam,
        style: AppTextStyles.body.copyWith(
          color: AppColors.white,
          height: 1.6,
        ),
        decoration: InputDecoration.collapsed(
          hintText:
              'Mark down the swell of your watch — the sounds, the distance '
              'from home, the small steadying moments...',
          hintStyle: AppTextStyles.body.copyWith(
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _SlateTools extends StatelessWidget {
  const _SlateTools();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              SvgPicture.asset(AppAssets.lock, width: 20, height: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Encrypted in local ship vault',
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            SvgPicture.asset(AppAssets.mic, width: 20, height: 20),
            const SizedBox(width: 8),
            SvgPicture.asset(AppAssets.camera, width: 20, height: 20),
          ],
        ),
      ],
    );
  }
}

class _PastEntries extends StatelessWidget {
  const _PastEntries({required this.loading, required this.entries});

  final bool loading;
  final List<JournalEntry> entries;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _stamp(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year} · '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAST LOG ENTRIES',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.cream),
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
        else if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.glassFillFaint,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppColors.glassBorderSoft),
            ),
            child: Text(
              'No logs filed yet. Your secured entries will surface here.',
              style: AppTextStyles.bodySmall,
            ),
          )
        else
          for (final entry in entries) ...[
            _PastEntryCard(stamp: _stamp(entry.createdAt), body: entry.body),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PastEntryCard extends StatelessWidget {
  const _PastEntryCard({required this.stamp, required this.body});

  final String stamp;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(AppAssets.mapPin, width: 14, height: 14),
              const SizedBox(width: 8),
              Text(stamp, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
