import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/local_prefs.dart';
import '../../core/data/usage_aggregates.dart';
import '../../core/data/usage_repository.dart';
import '../../core/format/token_format.dart';
import '../../core/models/daily_doc.dart';
import '../../core/models/usage_docs.dart';
import '../../core/ui/ut_kit.dart';
import '../auth/domain/mobile_auth.dart';
import 'insights_screens.dart';
import 'live_common.dart';

const appVersion = '0.1.0';

/// M09 — Settings.
class LiveSettingsScreen extends StatelessWidget {
  const LiveSettingsScreen({super.key, required this.args});
  final LiveArgs args;

  Future<void> _pickFormat(BuildContext context) async {
    final picked = await showModalBottomSheet<TokenFormat>(
      context: context,
      backgroundColor: UtColors.card,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final f in TokenFormat.values)
            ListTile(
              title: Text(
                  f == TokenFormat.compact
                      ? 'Compact · 6.83M'
                      : 'Full · 6,830,736',
                  style: UtText.bodyStrong),
              trailing: f == LocalPrefs.instance.tokenFormat
                  ? const Icon(Icons.check, color: UtColors.green)
                  : null,
              onTap: () => Navigator.pop(sheet, f),
            ),
        ]),
      ),
    );
    if (picked != null) await LocalPrefs.instance.setTokenFormat(picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = MobileAuthScope.maybeOf(context)?.user;
    final prefs = LocalPrefs.instance;
    return UtTabPage(
      title: 'Settings',
      subtitle: 'Account, display, and sync preferences',
      tabIndex: 3,
      body: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) => UtList(children: [
          UtCard(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const UtSectionLabel('General'),
                UtRowGroup(children: [
                  StreamBuilder<DateTime?>(
                    stream: args.repository.watchLastSync(uid: args.uid),
                    builder: (context, s) => UtRow(
                      title: 'μToken Companion',
                      actionName: 'Desktop connection',
                      subtitle: s.data == null
                          ? 'Not synced yet'
                          : 'Connected · ${relativeTime(s.data!, DateTime.now())}',
                      onTap: () => context.push('/desktop-connection'),
                    ),
                  ),
                  StreamBuilder<InsightsDoc?>(
                    stream: args.repository.watchInsights(uid: args.uid),
                    builder: (context, s) => UtRow(
                      title: 'AI suggestions',
                      subtitle: s.data == null
                          ? 'Set up in the desktop app'
                          : '${aiProviderName(s.data!.provider)}${s.data!.model == null ? '' : ' · ${s.data!.model}'}',
                      onTap: () => context.push('/ai-suggestions'),
                    ),
                  ),
                  const UtRow(title: 'Language', subtitle: 'System'),
                  UtRow(
                    title: 'Budget & alerts',
                    subtitle: prefs.monthlyBudgetUsd == null
                        ? 'No monthly limit'
                        : '${usd(prefs.monthlyBudgetUsd)} monthly',
                    onTap: () => context.push('/budget'),
                  ),
                ]),
                const UtDivider(),
                const SizedBox(height: 22),
                const UtSectionLabel('Usage'),
                UtRowGroup(children: [
                  UtRow(
                    title: 'Token numbers',
                    subtitle: prefs.tokenFormat == TokenFormat.compact
                        ? 'Compact'
                        : 'Full',
                    onTap: () => _pickFormat(context),
                  ),
                  UtRow(
                    title: 'Model pricing',
                    subtitle: 'Effective rates from your usage',
                    onTap: () => context.push('/model-pricing'),
                  ),
                  UtRow(
                    title: 'Privacy',
                    subtitle: 'Usage data only',
                    onTap: () => context.push('/privacy'),
                  ),
                ]),
                const UtDivider(),
                const SizedBox(height: 22),
                const UtSectionLabel('Account'),
                UtRow(
                  title: user?.email ?? 'Signed in',
                  actionName: 'Account',
                  subtitle: 'Google account',
                  onTap: () => context.push('/account'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// M10 — Desktop connection.
class LiveDesktopScreen extends StatelessWidget {
  const LiveDesktopScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: 'Desktop',
      subtitle: 'Collector and source status.',
      onBack: () => liveBack(context, '/settings'),
      children: [
        _DesktopStatus(args: args),
        const SizedBox(height: 16),
        UtStream<List<DailyDoc>>(
          stream: args.daily(),
          builder: (context, all) {
            final providers =
                byProvider(filterLastDays(all, 30, DateTime.now()));
            return UtCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(children: [
                const Row(children: [
                  Expanded(child: Text('Source', style: UtText.label)),
                  Text('Tokens · 30 days', style: UtText.label),
                ]),
                const SizedBox(height: 6),
                if (providers.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No uploads in the last 30 days.',
                          style: UtText.body)),
                for (final p in providers)
                  UtRow(
                      title: providerName(p.key),
                      trailing: UtValue(tok(p.value.tokens))),
              ]),
            );
          },
        ),
        const SizedBox(height: 28),
        const UtSectionLabel('Collector'),
        const UtCard(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
                title: 'Account link',
                subtitle:
                    'Desktop and phone sign in with the same Google account'),
            UtRow(
                title: 'Prompt content',
                subtitle: 'Never collected',
                trailing: UtPill('Off')),
          ]),
        ),
      ],
    );
  }
}

/// Connection card with a real "Sync now" that asks the desktop to upload.
class _DesktopStatus extends StatefulWidget {
  const _DesktopStatus({required this.args});
  final LiveArgs args;

  @override
  State<_DesktopStatus> createState() => _DesktopStatusState();
}

class _DesktopStatusState extends State<_DesktopStatus> {
  late final Stream<DateTime?> _lastSync =
      widget.args.repository.watchLastSync(uid: widget.args.uid);
  late final Stream<String?> _name =
      widget.args.repository.watchDesktopName(uid: widget.args.uid);
  Stream<SyncRequestStatus?>? _request;
  bool _sending = false;

  Future<void> _syncNow() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final id = await widget.args.repository.requestSync(uid: widget.args.uid);
      if (mounted) {
        setState(() => _request = widget.args.repository
            .watchSyncRequest(uid: widget.args.uid, id: id));
      }
    } catch (_) {
      if (mounted) utShowNotice(context, 'Couldn’t reach Firebase. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _requestText(SyncRequestStatus? r) => switch (r?.state) {
        'running' => 'Desktop is syncing…',
        'done' => 'Desktop finished syncing',
        'failed' => switch (r!.errorCode) {
            'network' => 'Desktop couldn’t reach Firebase',
            'revoked' => 'Desktop needs to sign in again',
            'not_paired' => 'Desktop is signed out',
            _ => 'Desktop sync failed',
          },
        _ => 'Waiting for the desktop to pick this up…',
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _name,
      builder: (context, name) => StreamBuilder<DateTime?>(
        stream: _lastSync,
        builder: (context, s) {
          final last = s.data;
          final now = DateTime.now();
          final fresh = last != null && now.difference(last).inHours < 24;
          final device = name.data ?? 'Desktop';
          return UtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: last == null
                              ? UtColors.muted
                              : fresh
                                  ? UtColors.green
                                  : UtColors.orange,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            last == null
                                ? 'Not synced yet'
                                : fresh
                                    ? 'Connected'
                                    : 'Sync is behind',
                            style: UtText.bodyStrong),
                        Text(
                            last == null
                                ? 'Sign in on desktop with this Google account'
                                : '$device · synced ${relativeTime(last, now)}',
                            style: UtText.caption),
                      ],
                    ),
                  ),
                  UtChipButtonSmall(
                      label: _sending ? 'Sending…' : 'Sync now',
                      onPressed: _syncNow),
                ]),
                if (_request != null)
                  StreamBuilder<SyncRequestStatus?>(
                    stream: _request,
                    builder: (context, r) => Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(children: [
                        if (r.data?.finished != true)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: UtColors.muted)),
                          ),
                        Expanded(
                          child: Text(_requestText(r.data),
                              key: const ValueKey('sync-request-status'),
                              style: UtText.caption.copyWith(
                                  color: r.data?.state == 'failed'
                                      ? UtColors.orange
                                      : r.data?.state == 'done'
                                          ? UtColors.green
                                          : UtColors.muted)),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Compact bordered button (Figma "Sync now": 88×34, r11).
class UtChipButtonSmall extends StatelessWidget {
  const UtChipButtonSmall(
      {super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
        color: UtColors.chip,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: const BorderSide(color: UtColors.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: utActionKey(label),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(label,
                style: UtText.caption.copyWith(color: UtColors.text)),
          ),
        ),
      );
}

/// Spending this calendar month, shared by Budget and Budget alert.
class BudgetStatus {
  BudgetStatus(List<DailyDoc> all, this.limit, DateTime now)
      : month = filterMonth(all, now)..sort((a, b) => a.date.compareTo(b.date)),
        daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day {
    spent = sumTotals(month).cost / 1e6;
  }
  final List<DailyDoc> month;
  final double? limit;
  final int daysLeft;
  late final double spent;

  double? get used => limit == null || limit == 0 ? null : spent / limit!;

  /// Day the cumulative cost first crossed [threshold] of the limit.
  String? reachedOn(double threshold) {
    if (limit == null) return null;
    var sum = 0.0;
    for (final d in month) {
      sum += (d.totals.costMicro ?? 0) / 1e6;
      if (sum >= limit! * threshold) return shortDate(d.date);
    }
    return null;
  }
}

/// M11 — Budget.
class LiveBudgetScreen extends StatefulWidget {
  const LiveBudgetScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  State<LiveBudgetScreen> createState() => _LiveBudgetScreenState();
}

class _LiveBudgetScreenState extends State<LiveBudgetScreen> {
  late final _controller = TextEditingController(
      text: LocalPrefs.instance.monthlyBudgetUsd?.toStringAsFixed(2) ?? '');
  late final Stream<List<DailyDoc>> _daily = widget.args.daily();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim().replaceAll('\$', '');
    final value = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (value == null || value <= 0)) {
      utShowNotice(context, 'Enter a monthly limit above \$0.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await LocalPrefs.instance.setMonthlyBudget(value);
    if (mounted) {
      utShowNotice(
          context,
          value == null
              ? 'Monthly limit removed.'
              : 'Monthly limit saved on this phone.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return UtPage(
      title: 'Budget',
      subtitle: 'Monthly spending limit and alerts.',
      onBack: () => liveBack(context, '/settings'),
      actions: [UtButton(label: 'Save', onPressed: _save)],
      children: [
        ListenableBuilder(
          listenable: LocalPrefs.instance,
          builder: (context, _) => UtStream<List<DailyDoc>>(
            stream: _daily,
            builder: (context, all) {
              final b =
                  BudgetStatus(all, LocalPrefs.instance.monthlyBudgetUsd, now);
              final used = b.used;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UtCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${monthName(now.month)} ${now.year}',
                            style: UtText.label),
                        const SizedBox(height: 8),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(usd(b.spent), style: UtText.code),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                    b.limit == null
                                        ? 'no limit set'
                                        : 'of ${usd(b.limit)}',
                                    style: UtText.body),
                              ),
                            ]),
                        const SizedBox(height: 16),
                        ShareBar(height: 8, parts: [
                          (
                            (used ?? 0).clamp(0, 1).toDouble(),
                            (used ?? 0) >= 0.7
                                ? UtColors.orange
                                : UtColors.green
                          ),
                          (
                            (1 - (used ?? 0)).clamp(0, 1).toDouble(),
                            UtColors.chip
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Text(
                              used == null
                                  ? 'Set a limit below'
                                  : '${pct(used)} used',
                              style: UtText.caption.copyWith(
                                  color: (used ?? 0) >= 0.7
                                      ? UtColors.orange
                                      : UtColors.muted)),
                          const Spacer(),
                          Text('${b.daysLeft} days left',
                              style: UtText.caption),
                        ]),
                      ],
                    ),
                  ),
                  if (used != null && used >= 0.9) ...[
                    const SizedBox(height: 12),
                    UtCard(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: UtRow(
                        leading: const Icon(Icons.warning_amber_rounded,
                            color: UtColors.orange),
                        title: 'Budget alert',
                        subtitle:
                            '${pct(used, digits: 0)} of your monthly limit used',
                        onTap: () => context.push('/budget-alert'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const UtSectionLabel('Alerts'),
                  UtCard(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: UtRowGroup(children: [
                      for (final t in const [0.7, 0.9, 1.0])
                        UtRow(
                          title: pct(t, digits: 0),
                          subtitle: b.reachedOn(t) == null
                              ? 'Not reached this month'
                              : 'Reached ${b.reachedOn(t)}',
                          trailing: b.reachedOn(t) == null
                              ? const UtPill('Watching')
                              : const UtPill('Reached', tone: UtTone.review),
                        ),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        const UtSectionLabel('Monthly limit'),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            key: const ValueKey('budget-limit-field'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: UtText.bodyStrong,
            cursorColor: UtColors.text,
            decoration: const InputDecoration(
              border: InputBorder.none,
              prefixText: '\$ ',
              prefixStyle: UtText.bodyStrong,
              hintText: 'e.g. 50.00',
              hintStyle: UtText.body,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Stored on this phone. Leave empty to remove the limit.',
            style: UtText.caption),
      ],
    );
  }
}

/// O02 — Budget alert.
class LiveBudgetAlertScreen extends StatelessWidget {
  const LiveBudgetAlertScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return UtPage(
      title: 'Budget alert',
      subtitle: 'Monthly usage compared with your limit.',
      onBack: () => liveBack(context, '/budget'),
      actions: [
        UtButton(
            label: 'View usage', onPressed: () => context.go('/analytics')),
        UtButton(
            label: 'Dismiss',
            style: UtButtonStyle.secondary,
            onPressed: () => liveBack(context, '/tokens')),
      ],
      children: [
        UtStream<List<DailyDoc>>(
          stream: args.daily(),
          builder: (context, all) {
            final b =
                BudgetStatus(all, LocalPrefs.instance.monthlyBudgetUsd, now);
            if (b.limit == null) {
              return UtMessage(
                  title: 'No monthly limit',
                  message: 'Set a limit to get budget alerts.',
                  action: UtButton(
                      label: 'Set limit',
                      onPressed: () => context.push('/budget')));
            }
            final week = byModel(filterLastDays(all, 7, now))
              ..sort((a, b) => b.value.cost.compareTo(a.value.cost));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${pct(b.used!, digits: 0)} used',
                          style: UtText.code.copyWith(
                              color: b.used! >= 0.9
                                  ? UtColors.orange
                                  : UtColors.text)),
                      const SizedBox(height: 6),
                      Text('${usd(b.spent)} of ${usd(b.limit)}',
                          style: UtText.body),
                      const SizedBox(height: 16),
                      Text(
                          b.spent >= b.limit!
                              ? '${usd(b.spent - b.limit!)} over the limit'
                              : '${usd(b.limit! - b.spent)} remaining',
                          style: UtText.bodyStrong),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const UtSectionLabel('Top contributor · last 7 days'),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: week.isEmpty
                      ? const UtRow(title: 'No usage this week')
                      : UtRow(
                          title: week.first.key,
                          trailing: UtValue(
                              '+${usd(week.first.value.costUsd)} this week',
                              color: UtColors.orange)),
                ),
                const SizedBox(height: 12),
                const Text(
                    'View the model breakdown before changing your tools.',
                    style: UtText.caption),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// M12 — Privacy.
class LivePrivacyScreen extends StatelessWidget {
  const LivePrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tick(bool on) => on
        ? const Icon(Icons.check, size: 16, color: UtColors.green)
        : const Text('—', style: UtText.bodyStrong);
    return UtPage(
      title: 'Privacy',
      subtitle: 'What is stored on your account.',
      onBack: () => liveBack(context, '/settings'),
      children: [
        const UtSectionLabel('Collected'),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
                title: 'Token counts',
                subtitle: 'Input, output, and cache',
                trailing: tick(true)),
            UtRow(
                title: 'Model and provider',
                subtitle: 'Used for breakdowns',
                trailing: tick(true)),
            UtRow(
                title: 'Time and latency',
                subtitle: 'Used for trends',
                trailing: tick(true)),
          ]),
        ),
        const SizedBox(height: 28),
        const UtSectionLabel('Not collected'),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
                title: 'Prompt text',
                subtitle: 'Stays on your device',
                trailing: tick(false)),
            UtRow(
                title: 'AI responses',
                subtitle: 'Stays on your device',
                trailing: tick(false)),
          ]),
        ),
        const SizedBox(height: 16),
        const Text(
            'Usage is stored as daily totals under your Google account in Firebase.',
            style: UtText.caption),
      ],
    );
  }
}

/// M13 — Account.
class LiveAccountScreen extends StatelessWidget {
  const LiveAccountScreen({super.key, required this.args});
  final LiveArgs args;

  Future<void> _signOut(BuildContext context, MobileAuthController auth) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('Sign out?'),
              content:
                  const Text('You can sign in again with your Google account.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Sign out')),
              ],
            ));
    if (confirmed == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = MobileAuthScope.maybeOf(context);
    final user = auth?.user;
    final name = user?.displayName ?? 'Signed in';
    return UtPage(
      title: 'Account',
      subtitle: 'Profile, data, and connected devices.',
      onBack: () => liveBack(context, '/settings'),
      actions: [
        if (auth != null)
          UtButton(
              label: 'Sign out',
              style: UtButtonStyle.secondary,
              onPressed: () => _signOut(context, auth)),
      ],
      children: [
        UtCard(
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 46,
                height: 46,
                child: user?.photoUrl == null
                    ? _Initial(name)
                    : Image.network(user!.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Initial(name)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: UtText.bodyStrong),
                  Text(user?.email ?? '', style: UtText.caption),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        const UtSectionLabel('Data'),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            StreamBuilder<DateTime?>(
              stream: args.repository.watchLastSync(uid: args.uid),
              builder: (context, s) => UtRow(
                title: 'Cloud sync',
                subtitle: 'Daily totals only',
                trailing: s.data == null
                    ? const UtPill('Waiting')
                    : const UtPill('Active', tone: UtTone.good),
              ),
            ),
            UtRow(
              title: 'Export',
              subtitle: 'CSV or JSON',
              onTap: () => context.push('/confirmations'),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        const UtSectionLabel('Account'),
        const UtCard(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(title: 'Google account', subtitle: 'Signed in with Google'),
            UtRow(title: 'App version', subtitle: 'Version $appVersion'),
          ]),
        ),
      ],
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: UtColors.text,
        child: Center(
          child: Text(
              name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
              style: UtText.title.copyWith(color: UtColors.background)),
        ),
      );
}

/// M14 — Model pricing, derived from synced cost and token totals.
class LiveModelPricingScreen extends StatelessWidget {
  const LiveModelPricingScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: 'Model pricing',
      subtitle: 'Effective cost per million tokens from your usage',
      onBack: () => liveBack(context, '/settings'),
      children: [
        UtStream<List<DailyDoc>>(
          stream: args.daily(),
          builder: (context, all) {
            final versions = all
                .map((d) => d.pricingVersion)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
            final providers = byProvider(all);
            if (providers.isEmpty) {
              return const UtMessage(
                  title: 'No priced usage yet',
                  message: 'Rates appear after the desktop uploads usage.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    versions.isEmpty
                        ? 'Price catalog version not reported'
                        : 'Price catalog · ${versions.last}',
                    style: UtText.caption),
                const SizedBox(height: 20),
                for (final p in providers) ...[
                  UtSectionLabel(providerName(p.key)),
                  UtCard(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: UtRowGroup(children: [
                      for (final m in groupBy(
                          all, (k) => k.provider == p.key ? k.model : null))
                        UtRow(
                          title: m.key,
                          subtitle:
                              '${tok(m.value.tokens)} tokens · ${usd(m.value.costUsd)}',
                          trailing: UtValue(m.value.tokens == 0 ||
                                  !m.value.costKnown
                              ? '—'
                              : '${usd(m.value.cost / m.value.tokens, digits: 2)} / MTok'),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                    'Effective rate = estimated cost ÷ tokens, so it blends input, cached and output prices. The desktop app prices each request from its saved catalog.',
                    style: UtText.caption),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// M15 — AI suggestions provider (configured on desktop).
class LiveAiSuggestionsScreen extends StatelessWidget {
  const LiveAiSuggestionsScreen({super.key, required this.args});
  final LiveArgs args;

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: 'AI suggestions',
      subtitle: 'Model used to write your suggestions.',
      onBack: () => liveBack(context, '/settings'),
      children: [
        UtStream<InsightsDoc?>(
          stream: args.repository.watchInsights(uid: args.uid),
          builder: (context, doc) {
            final status = switch (doc?.status) {
              'ok' => ('Working', UtTone.good),
              'insufficient_data' => ('Needs more usage', UtTone.neutral),
              'failed' => ('Failed', UtTone.danger),
              null => ('Not run yet', UtTone.neutral),
              final other => (other, UtTone.neutral),
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const UtSectionLabel('Provider'),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: UtRowGroup(children: [
                    for (final id in const ['openai', 'anthropic', 'google'])
                      UtRow(
                        title: aiProviderName(id),
                        subtitle: switch (id) {
                          'openai' => 'GPT models',
                          'anthropic' => 'Claude models',
                          _ => 'Gemini models',
                        },
                        trailing: doc?.provider == id
                            ? const Icon(Icons.check,
                                size: 16, color: UtColors.green)
                            : null,
                      ),
                  ]),
                ),
                const SizedBox(height: 28),
                const UtSectionLabel('Latest review'),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: UtRowGroup(children: [
                    UtRow(title: 'Model', subtitle: doc?.model ?? '—'),
                    UtRow(
                        title: 'Status',
                        subtitle: doc?.generatedAt.isNotEmpty == true
                            ? 'Generated ${doc!.generatedAt.replaceFirst('T', ' ').split('.').first}'
                            : 'No review uploaded',
                        trailing: UtPill(status.$1, tone: status.$2)),
                    if (doc?.score != null)
                      UtRow(
                          title: 'Review score',
                          trailing: UtValue(
                              '${doc!.score!.toStringAsFixed(0)}${doc.grade == null ? '' : ' · ${doc.grade}'}')),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text(
                    'Change the provider, model and API key in Settings › AI review on the desktop app. The API key stays on your computer, not in Firebase.',
                    style: UtText.caption),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// O01 — Export this month's daily records.
class LiveExportScreen extends StatelessWidget {
  const LiveExportScreen({super.key, required this.args});
  final LiveArgs args;

  static String toCsv(List<DailyDoc> docs) {
    final rows = [
      'date,input,cached,cache_write,output,chats,requests,cost_usd',
      for (final d in docs)
        [
          d.date,
          d.totals.input,
          d.totals.cached,
          d.totals.cacheWrite,
          d.totals.output,
          d.totals.chats,
          d.totals.requests,
          d.totals.costMicro == null
              ? ''
              : (d.totals.costMicro! / 1e6).toStringAsFixed(6),
        ].join(','),
    ];
    return rows.join('\n');
  }

  static String toJson(List<DailyDoc> docs) =>
      const JsonEncoder.withIndent('  ').convert([
        for (final d in docs)
          {
            'date': d.date,
            'input': d.totals.input,
            'cached': d.totals.cached,
            'cache_write': d.totals.cacheWrite,
            'output': d.totals.output,
            'chats': d.totals.chats,
            'requests': d.totals.requests,
            'cost_micro': d.totals.costMicro,
            'by_key': {
              for (final e in d.byKey.entries)
                e.key: {
                  'input': e.value.input,
                  'output': e.value.output,
                  'cost_micro': e.value.costMicro,
                }
            },
          }
      ]);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return UtStream<List<DailyDoc>>(
      stream: args.daily(),
      builder: (context, all) {
        final docs = filterMonth(all, now)
          ..sort((a, b) => a.date.compareTo(b.date));
        final t = sumTotals(docs);
        final providers = byProvider(docs);
        Future<void> copy(String kind, String text) async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            utShowNotice(
                context, 'Copied ${docs.length} daily records as $kind.');
          }
        }

        return UtPage(
          title: 'Export',
          subtitle: 'Copy your usage data for this month.',
          onBack: () => liveBack(context, '/account'),
          actions: [
            UtButton(
                label: 'Copy CSV',
                actionName: 'Download CSV',
                onPressed:
                    docs.isEmpty ? null : () => copy('CSV', toCsv(docs))),
            UtButton(
                label: 'Copy JSON',
                actionName: 'Download JSON',
                style: UtButtonStyle.secondary,
                onPressed:
                    docs.isEmpty ? null : () => copy('JSON', toJson(docs))),
          ],
          children: [
            const SizedBox(height: 16),
            const Center(
                child: Icon(Icons.file_download_outlined,
                    size: 40, color: UtColors.muted)),
            const SizedBox(height: 20),
            Text(docs.isEmpty ? 'Nothing to export' : 'Ready to export',
                textAlign: TextAlign.center, style: UtText.title),
            const SizedBox(height: 6),
            Text(
                '${docs.length} daily records · ${monthName(now.month)} ${now.year}',
                textAlign: TextAlign.center,
                style: UtText.body),
            const SizedBox(height: 28),
            UtCard(
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child:
                          MiniStat(value: compact(t.tokens), label: 'Tokens')),
                  Expanded(
                      child: MiniStat(value: usd(t.costUsd), label: 'Cost')),
                  Expanded(
                      child: MiniStat(value: '${docs.length}', label: 'Days')),
                ]),
                const SizedBox(height: 18),
                const UtDivider(),
                const SizedBox(height: 14),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Provider mix', style: UtText.label)),
                const SizedBox(height: 10),
                ShareBar(parts: [
                  for (var i = 0; i < providers.length; i++)
                    (
                      share(providers[i].value.tokens, t.tokens),
                      providerColor(i)
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  for (var i = 0; i < providers.length; i++)
                    Expanded(
                        child: Text(
                            '${providerName(providers[i].key)} ${pct(share(providers[i].value.tokens, t.tokens), digits: 0)}',
                            style: UtText.caption)),
                ]),
              ]),
            ),
          ],
        );
      },
    );
  }
}

/// O03 — Estimated cost breakdown for the selected period.
class LiveCostBreakdownScreen extends StatelessWidget {
  const LiveCostBreakdownScreen(
      {super.key, required this.args, this.period = UsagePeriod.month});
  final LiveArgs args;
  final UsagePeriod period;

  @override
  Widget build(BuildContext context) {
    return UtPage(
      title: 'Estimated cost',
      subtitle: '${period.label} · by model',
      onBack: () => liveBack(context, '/tokens'),
      actions: [
        UtButton(
            label: 'View model pricing',
            style: UtButtonStyle.secondary,
            onPressed: () => context.push('/model-pricing')),
      ],
      children: [
        UtStream<List<DailyDoc>>(
          stream: args.daily(),
          builder: (context, all) {
            final docs = filterPeriod(all, period, DateTime.now());
            final t = sumTotals(docs);
            final models = byModel(docs)
              ..sort((a, b) => b.value.cost.compareTo(a.value.cost));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated cost', style: UtText.label),
                      const SizedBox(height: 8),
                      Text(usdSmart(t.costUsd), style: UtText.code),
                      Text('${tok(t.tokens)} tokens', style: UtText.caption),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: UtRowGroup(children: [
                    if (models.isEmpty)
                      const UtRow(title: 'No usage in this period'),
                    for (final m in models)
                      UtRow(
                        title: m.key,
                        subtitle:
                            '${compact(m.value.input)} in · ${compact(m.value.cached)} cached · ${compact(m.value.output)} out',
                        trailing: UtValue(usdSmart(m.value.costUsd)),
                      ),
                    if (models.isNotEmpty) ...[
                      const UtDivider(),
                      UtRow(
                          title: 'Total estimated',
                          trailing: UtValue(usdSmart(t.costUsd))),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                const Text(
                    'Based on the price catalog saved on your desktop. Final bills from providers may differ.',
                    style: UtText.caption),
              ],
            );
          },
        ),
      ],
    );
  }
}
