import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_icon_button.dart';

/// "Safe Harbor Chat" anonymous crew chat (Figma node 10:89 "anonymous-chat").
///
/// Reached from the community-connect screen (its "Cast to Fleet" action),
/// as it is the crew's private, anonymised conversation surface.
class AnonymousChatScreen extends StatelessWidget {
  const AnonymousChatScreen({super.key});

  static const List<_Message> _thread = [
    _Message(
      author: 'Quiet Lighthouse',
      time: '07:45 AM',
      text:
          'Day 40 at sea. Staring into the gray horizon gets heavy. Anyone '
          'else on watch right now?',
    ),
    _Message(
      author: 'Distant Shore',
      time: '07:51 AM',
      text:
          "Aye, on watch in the Pacific. Waves are high tonight, but "
          "Tidewell's breathing session helped me anchor my chest.",
    ),
    _Message(
      author: 'Calm Harbor',
      time: '07:55 AM',
      text:
          "I'm heading home next week after 6 months. It gets easier, "
          'friends. Hold fast, the tide always turns.',
      isOwn: true,
    ),
    _Message(
      author: 'Quiet Lighthouse',
      time: '07:59 AM',
      text:
          'Safe voyages, Calm Harbor. Needed to hear that. Just a few more '
          'weeks for me.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.appBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => Navigator.of(context).maybePop()),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: _SafetyCard(),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  itemCount: _thread.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (_, i) => _ChatBubble(message: _thread[i]),
                ),
              ),
              const _Composer(),
            ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassIconButton(icon: AppAssets.arrowLeft, onTap: onBack),
              Flexible(
                child: Text(
                  'Safe Harbor Chat',
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
            'Private frequency for passing sailors',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealFaintSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Row(
        children: [
          SvgPicture.asset(AppAssets.circleX, width: 20, height: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Safe Harbor Chat — Your identity stays private. Keep '
              'conversations supportive.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  const _Message({
    required this.author,
    required this.time,
    required this.text,
    this.isOwn = false,
  });

  final String author;
  final String time;
  final String text;
  final bool isOwn;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final align = message.isOwn
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.author,
              style: AppTextStyles.nameTag.copyWith(
                color: message.isOwn ? AppColors.seafoam : AppColors.cream,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              message.time,
              style: AppTextStyles.navLabel.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: message.isOwn ? AppColors.teal : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: message.isOwn
                ? null
                : Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            message.text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Whisper to the sea anonymously...',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        SvgPicture.asset(
                          AppAssets.smilePlus,
                          width: 20,
                          height: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: AppColors.teal,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {},
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: SvgPicture.asset(
                          AppAssets.send,
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            AppColors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  AppAssets.anchor,
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    AppColors.muted,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'In partnership with International Maritime Welfare',
                    style: AppTextStyles.navLabel.copyWith(
                      color: AppColors.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
