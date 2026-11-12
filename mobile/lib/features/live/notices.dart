import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/local_prefs.dart';
import '../../core/data/usage_aggregates.dart';
import '../../core/i18n/tr.dart';
import '../../core/models/usage_docs.dart';
import '../../core/ui/ut_kit.dart';
import 'live_common.dart';
import 'sync_banners.dart';

Color noticeColor(String level) => switch (level) {
      'critical' => const Color(0xFFEF6461),
      'warning' => UtColors.orange,
      _ => UtColors.blue,
    };

IconData noticeIcon(String level) => switch (level) {
      'critical' => Icons.error_outline_rounded,
      'warning' => Icons.warning_amber_rounded,
      _ => Icons.campaign_outlined,
    };

/// Live notices with an empty list until the first snapshot, so screens never
/// wait on them.
Widget withNotices(LiveArgs args,
        Widget Function(BuildContext context, List<Notice> notices) builder) =>
    StreamBuilder<List<Notice>>(
      stream: args.repository.watchNotices(uid: args.uid),
      initialData: const [],
      builder: (context, snap) => ListenableBuilder(
        listenable: LocalPrefs.instance,
        builder: (context, _) => builder(context, snap.data ?? const []),
      ),
    );

/// Newest unread notice on top of the Tokens tab; "Later" hides it.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) => withNotices(args, (context, notices) {
        final unread = notices
            .where((n) => !LocalPrefs.instance.isNoticeRead(n.id))
            .toList();
        if (unread.isEmpty) return const SizedBox.shrink();
        final n = unread.first;
        return SyncBannerCard(
          key: ValueKey('notice-${n.id}'),
          icon: noticeIcon(n.level),
          color: noticeColor(n.level),
          title: n.title,
          message: n.body,
          actions: [
            UtChipButtonSmall(
                label: unread.length > 1
                    ? tr('View all ({n})', {'n': unread.length})
                    : tr('Details'),
                onPressed: () => context.push('/notifications')),
            UtChipButtonSmall(
                label: tr('Dismiss'),
                onPressed: () => LocalPrefs.instance.markNoticesRead([n.id])),
          ],
        );
      });
}

/// Bell in the tab header; the badge counts unread notices.
class NoticeBell extends StatelessWidget {
  const NoticeBell({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) => withNotices(args, (context, notices) {
        final unread = notices
            .where((n) => !LocalPrefs.instance.isNoticeRead(n.id))
            .length;
        return UtIconButton(
          icon: unread > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
          label: tr('Notifications'),
          badge: unread,
          onPressed: () => context.push('/notifications'),
        );
      });
}

/// Settings row with the unread count.
class NoticesRow extends StatelessWidget {
  const NoticesRow({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) => withNotices(args, (context, notices) {
        final unread = notices
            .where((n) => !LocalPrefs.instance.isNoticeRead(n.id))
            .length;
        return UtRow(
          title: tr('Notifications'),
          actionName: 'Notifications',
          subtitle: notices.isEmpty
              ? tr('No notifications')
              : unread == 0
                  ? tr('All read')
                  : tr('{n} unread', {'n': unread}),
          onTap: () => context.push('/notifications'),
        );
      });
}

/// Every active notice; opening the page marks them read.
class LiveNoticesScreen extends StatefulWidget {
  const LiveNoticesScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  State<LiveNoticesScreen> createState() => _LiveNoticesScreenState();
}

class _LiveNoticesScreenState extends State<LiveNoticesScreen> {
  /// Unread when the page opened, so they stay highlighted while reading.
  Set<String>? _freshOnOpen;

  @override
  Widget build(BuildContext context) => UtPage(
        title: tr('Notifications'),
        subtitle: tr('Messages from the μToken team.'),
        onBack: () => liveBack(context, '/settings'),
        children: [
          withNotices(widget.args, (context, notices) {
            final prefs = LocalPrefs.instance;
            final fresh = {
              ...?_freshOnOpen,
              for (final n in notices)
                if (!prefs.isNoticeRead(n.id)) n.id
            };
            _freshOnOpen = fresh;
            if (fresh.any((id) => !prefs.isNoticeRead(id))) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => prefs.markNoticesRead(fresh));
            }
            if (notices.isEmpty) {
              return UtMessage(
                  icon: Icons.notifications_none_rounded,
                  title: tr('No notifications'),
                  message: tr('Announcements from the team will appear here.'));
            }
            return Column(children: [
              for (final n in notices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NoticeCard(notice: n, fresh: fresh.contains(n.id)),
                ),
            ]);
          }),
        ],
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.fresh});
  final Notice notice;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final color = noticeColor(notice.level);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UtColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: fresh ? color.withValues(alpha: 0.5) : UtColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(noticeIcon(notice.level), size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(notice.title, style: UtText.bodyStrong)),
            if (fresh)
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 8),
          Text(notice.body,
              style: UtText.body.copyWith(color: UtColors.text, height: 1.5)),
          const SizedBox(height: 10),
          Text(
              [
                if (notice.personal) tr('Sent to you'),
                if (notice.createdAt != null)
                  relativeTime(notice.createdAt!, DateTime.now()),
              ].join(' · '),
              style: UtText.caption),
        ],
      ),
    );
  }
}
