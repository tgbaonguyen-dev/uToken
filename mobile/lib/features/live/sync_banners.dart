import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/tr.dart';
import '../../core/ui/ut_kit.dart';
import 'live_common.dart';

/// Card used by the S03/S04/stale banners above the Tokens data.
class SyncBannerCard extends StatelessWidget {
  const SyncBannerCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actions = const [],
    this.progress = false,
  });

  final IconData icon;
  final Color color;
  final String title, message;
  final List<Widget> actions;
  final bool progress;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: UtCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: UtText.bodyStrong),
                      const SizedBox(height: 2),
                      Text(message, style: UtText.caption),
                    ],
                  ),
                ),
              ]),
              if (progress) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                      minHeight: 3,
                      color: color,
                      backgroundColor: UtColors.cardBorder),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      );
}

/// S03 — a sync request is out; old data stays visible below.
class SyncingBanner extends StatelessWidget {
  const SyncingBanner({super.key, required this.sync});
  final SyncCenter sync;

  @override
  Widget build(BuildContext context) => SyncBannerCard(
        key: const ValueKey('s03-syncing'),
        icon: Icons.sync_rounded,
        color: UtColors.blue,
        progress: true,
        title: sync.requestState == 'running'
            ? tr('Syncing usage…')
            : tr('Waiting for your desktop…'),
        message: sync.requestState == 'running'
            ? tr(
                'Your desktop is uploading new usage. This page updates by itself.')
            : tr('Asked μToken on your computer to upload new usage.'),
      );
}

/// S04 — the desktop didn't answer or failed; offers Retry and Desktop.
class SyncFailedBanner extends StatelessWidget {
  const SyncFailedBanner({super.key, required this.sync});
  final SyncCenter sync;

  @override
  Widget build(BuildContext context) => SyncBannerCard(
        key: const ValueKey('s04-sync-failed'),
        icon: Icons.sync_problem_rounded,
        color: UtColors.orange,
        title: tr('Couldn’t sync latest usage'),
        message: tr('{reason} Showing the last synced data.',
            {'reason': syncErrorText(sync.errorCode)}),
        actions: [
          UtChipButtonSmall(label: tr('Retry sync'), onPressed: sync.start),
          UtChipButtonSmall(
              label: tr('Desktop connection'),
              onPressed: () => context.push('/desktop-connection')),
        ],
      );
}
