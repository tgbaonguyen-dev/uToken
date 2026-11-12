import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/local_prefs.dart';
import '../../core/data/usage_aggregates.dart';
import '../../core/format/token_format.dart';
import '../../core/models/daily_doc.dart';
import '../../core/data/stream_status.dart';
import '../../core/ui/ut_kit.dart';
import '../../core/firebase/crash_reporter.dart';
import '../../core/i18n/tr.dart';
import '../ai_review/judge.dart';
import '../ai_review/phone_judge.dart';
import '../auth/domain/mobile_auth.dart';
import 'insights_screens.dart';
import 'notices.dart';
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
                      ? tr('Compact · 6.83M')
                      : tr('Full · 6,830,736'),
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

  Future<void> _pickLanguage(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: UtColors.card,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (code, name) in const [
            ('en', 'English'),
            ('vi', 'Tiếng Việt')
          ])
            ListTile(
              key: ValueKey('language-$code'),
              title: Text(name, style: UtText.bodyStrong),
              trailing: code == LocalPrefs.instance.language
                  ? const Icon(Icons.check, color: UtColors.green)
                  : null,
              onTap: () => Navigator.pop(sheet, code),
            ),
        ]),
      ),
    );
    if (picked != null) await LocalPrefs.instance.setLanguage(picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = MobileAuthScope.maybeOf(context)?.user;
    final prefs = LocalPrefs.instance;
    return UtTabPage(
      trailing: NoticeBell(args: args),
      title: tr('Settings'),
      subtitle: tr('Account, display, and sync preferences'),
      tabIndex: 3,
      body: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) => UtList(children: [
          UtCard(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UtSectionLabel(tr('General')),
                UtRowGroup(children: [
                  NoticesRow(args: args),
                  StreamBuilder<DateTime?>(
                    stream: args.repository.watchLastSync(uid: args.uid),
                    builder: (context, s) => UtRow(
                      title: tr('μToken Companion'),
                      actionName: 'Desktop connection',
                      subtitle: s.data == null
                          ? tr('Not synced yet')
                          : tr('Connected · {when}',
                              {'when': relativeTime(s.data!, DateTime.now())}),
                      onTap: () => context.push('/desktop-connection'),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: PhoneJudge.instance,
                    builder: (context, _) => UtRow(
                      title: tr('AI review'),
                      actionName: 'AI suggestions',
                      subtitle: PhoneJudge.instance.hasKey
                          ? '${aiProviderName(PhoneJudge.instance.provider)} · ${PhoneJudge.instance.model}'
                          : tr('Not set up · add an API key'),
                      onTap: () => context.push('/ai-suggestions'),
                    ),
                  ),
                  UtRow(
                    title: tr('Language'),
                    subtitle: prefs.vietnamese ? tr('Tiếng Việt') : 'English',
                    onTap: () => _pickLanguage(context),
                  ),
                  UtRow(
                    title: tr('Budget & alerts'),
                    subtitle: prefs.monthlyBudgetUsd == null
                        ? tr('No monthly limit')
                        : tr('{amount} monthly',
                            {'amount': usd(prefs.monthlyBudgetUsd)}),
                    onTap: () => context.push('/budget'),
                  ),
                ]),
                const UtDivider(),
                const SizedBox(height: 22),
                UtSectionLabel(tr('Usage')),
                UtRowGroup(children: [
                  UtRow(
                    title: tr('Token numbers'),
                    subtitle: prefs.tokenFormat == TokenFormat.compact
                        ? tr('Compact')
                        : tr('Full'),
                    onTap: () => _pickFormat(context),
                  ),
                  UtRow(
                    title: tr('Model pricing'),
                    subtitle: tr('Effective rates from your usage'),
                    onTap: () => context.push('/model-pricing'),
                  ),
                  UtRow(
                    title: tr('Privacy'),
                    subtitle: tr('Usage data only'),
                    onTap: () => context.push('/privacy'),
                  ),
                ]),
                const UtDivider(),
                const SizedBox(height: 22),
                UtSectionLabel(tr('Account')),
                UtRow(
                  title: user?.email ?? tr('Signed in'),
                  actionName: 'Account',
                  subtitle: tr('Google account'),
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
      title: tr('Desktop'),
      subtitle: tr('Collector and source status.'),
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
                Row(children: [
                  Expanded(child: Text(tr('Source'), style: UtText.label)),
                  Text(tr('Tokens · 30 days'), style: UtText.label),
                ]),
                const SizedBox(height: 6),
                if (providers.isEmpty)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(tr('No uploads in the last 30 days.'),
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
        UtSectionLabel(tr('Collector')),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
                title: tr('Account link'),
                subtitle: tr(
                    'Desktop and phone sign in with the same Google account')),
            UtRow(
                title: tr('Prompt content'),
                subtitle: tr('Never collected'),
                trailing: UtPill(tr('Off'))),
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
  late final SyncCenter _sync = widget.args.sync;
  bool _touched = false;

  Future<void> _syncNow() async {
    setState(() => _touched = true);
    await _sync.start();
  }

  String _requestText() => switch (_sync.phase) {
        SyncPhase.failed => syncErrorText(_sync.errorCode),
        SyncPhase.idle => tr('Desktop finished syncing'),
        SyncPhase.syncing => _sync.requestState == 'running'
            ? tr('Desktop is syncing…')
            : tr('Waiting for the desktop to pick this up…'),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _sync,
        builder: (context, _) => StreamBuilder<String?>(
              stream: _name,
              builder: (context, name) => StreamBuilder<DateTime?>(
                stream: _lastSync,
                builder: (context, s) {
                  final last = s.data;
                  final now = DateTime.now();
                  final fresh =
                      last != null && now.difference(last).inHours < 24;
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
                                        ? tr('Not synced yet')
                                        : fresh
                                            ? tr('Connected')
                                            : tr('Sync is behind'),
                                    style: UtText.bodyStrong),
                                Text(
                                    last == null
                                        ? tr(
                                            'Sign in on desktop with this Google account')
                                        : tr('{device} · synced {when}', {
                                            'device': device,
                                            'when': relativeTime(last, now)
                                          }),
                                    style: UtText.caption),
                              ],
                            ),
                          ),
                          UtChipButtonSmall(
                              label:
                                  _sync.busy ? tr('Syncing…') : tr('Sync now'),
                              onPressed: _syncNow),
                        ]),
                        if (_touched || _sync.phase != SyncPhase.idle)
                          Builder(
                            builder: (context) => Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Row(children: [
                                if (_sync.busy)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 10),
                                    child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: UtColors.muted)),
                                  ),
                                Expanded(
                                  child: Text(_requestText(),
                                      key:
                                          const ValueKey('sync-request-status'),
                                      style: UtText.caption.copyWith(
                                          color: _sync.phase == SyncPhase.failed
                                              ? UtColors.orange
                                              : _sync.phase == SyncPhase.idle
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
            ));
  }
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

class _LiveBudgetScreenState extends State<LiveBudgetScreen>
    with DayRollover<LiveBudgetScreen> {
  @override
  DateTime get localNow => widget.args.now();
  @override
  void onDayChanged() => _daily = widget.args.daily();
  late final _controller = TextEditingController(
      text: LocalPrefs.instance.monthlyBudgetUsd?.toStringAsFixed(2) ?? '');
  late Stream<List<DailyDoc>> _daily = widget.args.daily();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim().replaceAll('\$', '');
    final value = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (value == null || value <= 0)) {
      utShowNotice(context, tr('Enter a monthly limit above \$0.'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await LocalPrefs.instance.setMonthlyBudget(value);
    if (mounted) {
      utShowNotice(
          context,
          LocalPrefs.instance.saveError != null
              ? tr('Could not save preferences. Use Retry above.')
              : value == null
                  ? tr('Monthly limit removed.')
                  : tr('Monthly limit saved on this phone.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = localNow;
    return UtPage(
      title: tr('Budget'),
      subtitle: tr('Monthly spending limit and alerts.'),
      onBack: () => liveBack(context, '/settings'),
      actions: [UtButton(label: tr('Save'), onPressed: _save)],
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
                        Text(monthYear(now), style: UtText.label),
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
                                        ? tr('no limit set')
                                        : tr('of {limit}',
                                            {'limit': usd(b.limit)}),
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
                                  ? tr('Set a limit below')
                                  : tr('{p} used', {'p': pct(used)}),
                              style: UtText.caption.copyWith(
                                  color: (used ?? 0) >= 0.7
                                      ? UtColors.orange
                                      : UtColors.muted)),
                          const Spacer(),
                          Text(tr('{n} days left', {'n': b.daysLeft}),
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
                        title: tr('Budget alert'),
                        subtitle: tr('{p} of your monthly limit used',
                            {'p': pct(used, digits: 0)}),
                        onTap: () => context.push('/budget-alert'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  UtSectionLabel(tr('Alerts')),
                  UtCard(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: UtRowGroup(children: [
                      for (final t in const [0.7, 0.9, 1.0])
                        UtRow(
                          title: pct(t, digits: 0),
                          subtitle: b.reachedOn(t) == null
                              ? tr('Not reached this month')
                              : tr('Reached {d}', {'d': b.reachedOn(t)}),
                          trailing: b.reachedOn(t) == null
                              ? UtPill(tr('Watching'))
                              : UtPill(tr('Reached'), tone: UtTone.review),
                        ),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        UtSectionLabel(tr('Monthly limit')),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            key: const ValueKey('budget-limit-field'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: UtText.bodyStrong,
            cursorColor: UtColors.text,
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixText: '\$ ',
              prefixStyle: UtText.bodyStrong,
              hintText: tr('e.g. 50.00'),
              hintStyle: UtText.body,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: 10),
        Text(tr('Stored on this phone. Leave empty to remove the limit.'),
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
      title: tr('Budget alert'),
      subtitle: tr('Monthly usage compared with your limit.'),
      onBack: () => liveBack(context, '/budget'),
      actions: [
        UtButton(
            label: tr('View usage'), onPressed: () => context.go('/analytics')),
        UtButton(
            label: tr('Dismiss'),
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
                  title: tr('No monthly limit'),
                  message: tr('Set a limit to get budget alerts.'),
                  action: UtButton(
                      label: tr('Set limit'),
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
                      Text(tr('{p} used', {'p': pct(b.used!, digits: 0)}),
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
                              ? tr('{amount} over the limit',
                                  {'amount': usd(b.spent - b.limit!)})
                              : tr('{amount} remaining',
                                  {'amount': usd(b.limit! - b.spent)}),
                          style: UtText.bodyStrong),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                UtSectionLabel(tr('Top contributor · last 7 days')),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: week.isEmpty
                      ? UtRow(title: tr('No usage this week'))
                      : UtRow(
                          title: week.first.key,
                          trailing: UtValue(
                              tr('+{amount} this week',
                                  {'amount': usd(week.first.value.costUsd)}),
                              color: UtColors.orange)),
                ),
                const SizedBox(height: 12),
                Text(tr('View the model breakdown before changing your tools.'),
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
      title: tr('Privacy'),
      subtitle: tr('What is stored on your account.'),
      onBack: () => liveBack(context, '/settings'),
      children: [
        UtSectionLabel(tr('Collected')),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
                title: tr('Token counts'),
                subtitle: tr('Input, output, and cache'),
                trailing: tick(true)),
            UtRow(
                title: tr('Model and provider'),
                subtitle: tr('Used for breakdowns'),
                trailing: tick(true)),
            UtRow(
                title: tr('Time and latency'),
                subtitle: tr('Used for trends'),
                trailing: tick(true)),
          ]),
        ),
        const SizedBox(height: 28),
        UtSectionLabel(tr('Not collected')),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
                title: tr('Prompt text'),
                subtitle: tr('Stays on your device'),
                trailing: tick(false)),
            UtRow(
                title: tr('AI responses'),
                subtitle: tr('Stays on your device'),
                trailing: tick(false)),
          ]),
        ),
        const SizedBox(height: 16),
        Text(
            tr('Usage is stored as daily totals under your Google account in Firebase.'),
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
              title: Text(tr('Sign out?')),
              content:
                  Text(tr('You can sign in again with your Google account.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(tr('Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(tr('Sign out'))),
              ],
            ));
    if (confirmed == true) await auth.signOut();
  }

  Future<void> _testCrash(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text(tr('Crash the app?')),
              content: Text(tr(
                  'The app will close immediately. The crash is reported to Firebase Crashlytics and logged in Firestore.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(tr('Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(tr('Crash'))),
              ],
            ));
    if (confirmed != true) return;
    await CrashReporter.triggerTestCrash(
        uid: args.uid, appVersion: appVersion, screen: 'account');
  }

  @override
  Widget build(BuildContext context) {
    final auth = MobileAuthScope.maybeOf(context);
    final user = auth?.user;
    final name = user?.displayName ?? 'Signed in';
    return UtPage(
      title: tr('Account'),
      subtitle: tr('Profile, data, and connected devices.'),
      onBack: () => liveBack(context, '/settings'),
      actions: [
        if (auth != null)
          UtButton(
              label: tr('Sign out'),
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
        UtSectionLabel(tr('Data')),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            StreamBuilder<DateTime?>(
              stream: args.repository.watchLastSync(uid: args.uid),
              builder: (context, s) => UtRow(
                title: tr('Cloud sync'),
                subtitle: tr('Daily totals only'),
                trailing: s.data == null
                    ? UtPill(tr('Waiting'))
                    : UtPill(tr('Active'), tone: UtTone.good),
              ),
            ),
            UtRow(
              title: tr('Export'),
              subtitle: tr('CSV or JSON'),
              onTap: () => context.push('/confirmations'),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        UtSectionLabel(tr('Account')),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
                title: tr('Google account'),
                subtitle: tr('Signed in with Google')),
            UtRow(
                title: tr('App version'),
                subtitle: tr('Version {v}', {'v': appVersion})),
          ]),
        ),
        const SizedBox(height: 28),
        UtSectionLabel(tr('Diagnostics')),
        UtCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: UtRowGroup(children: [
            UtRow(
              title: tr('Test crash'),
              subtitle: tr('Crash the app and report it to Firebase'),
              onTap: () => _testCrash(context),
            ),
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
      title: tr('Model pricing'),
      subtitle: tr('Effective cost per million tokens from your usage'),
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
              return UtMessage(
                  title: tr('No priced usage yet'),
                  message: tr('Rates appear after the desktop uploads usage.'));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    versions.isEmpty
                        ? tr('Price catalog version not reported')
                        : tr('Price catalog · {v}', {'v': versions.last}),
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
                Text(
                    tr('Effective rate = estimated cost ÷ tokens, so it blends input, cached and output prices. The desktop app prices each request from its saved catalog.'),
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
class LiveAiSuggestionsScreen extends StatefulWidget {
  const LiveAiSuggestionsScreen({super.key, required this.args});
  final LiveArgs args;
  @override
  State<LiveAiSuggestionsScreen> createState() =>
      _LiveAiSuggestionsScreenState();
}

/// M15 — AI review on this phone: provider, model, API key, test (FR-AIKEY-001).
class _LiveAiSuggestionsScreenState extends State<LiveAiSuggestionsScreen> {
  final _judge = PhoneJudge.instance;
  late String _provider = _judge.provider;
  late final _model = TextEditingController(text: _judge.model);
  final _key = TextEditingController();
  bool _showKey = false, _testing = false, _saving = false;
  String? _testResult; // null = not tested, '' = ok, else error code

  @override
  void dispose() {
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  void _pickProvider(String p) {
    if (p == _provider) return;
    setState(() {
      _provider = p;
      _model.text = defaultJudgeModel(p);
      _key.clear();
      _testResult = null;
    });
  }

  bool get _keyIsSaved => _provider == _judge.provider && _judge.hasKey;

  Future<void> _test() async {
    final key = _key.text.trim();
    if (key.isEmpty && !_keyIsSaved) {
      setState(() => _testResult = 'missing_key');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    String? code;
    if (key.isEmpty) {
      // Test the saved key: save model/provider first, then run the check.
      code = await _judge.testSaved(provider: _provider, model: _model.text);
    } else {
      code = await _judge.test(
          provider: _provider, model: _model.text.trim(), apiKey: key);
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = code ?? '';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final key = _key.text.trim();
    await _judge.save(
        provider: _provider,
        model: _model.text,
        apiKey: key.isEmpty ? null : key);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _key.clear();
    });
    HapticFeedback.lightImpact();
    utShowNotice(context, tr('AI settings saved on this phone.'));
  }

  Future<void> _remove() async {
    await _judge.removeKey();
    if (mounted) setState(() => _testResult = null);
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_testResult) {
      null => null,
      '' => (tr('Connected'), UtTone.good),
      'invalid_api_key' => (tr('Invalid API key'), UtTone.danger),
      'invalid_model' => (tr('Model not found'), UtTone.danger),
      'missing_key' => (tr('Enter an API key first'), UtTone.review),
      final code => (friendlyAiError(code), UtTone.danger),
    };
    return ListenableBuilder(
      listenable: _judge,
      builder: (context, _) => UtPage(
        title: tr('AI review'),
        subtitle: tr('Runs on this phone with your own API key.'),
        onBack: () => liveBack(context, '/settings'),
        children: [
          UtSectionLabel(tr('Provider')),
          UtSegmented<String>(
            values: judgeProviders,
            selected: _provider,
            label: (p) => switch (p) {
              'google' => tr('Gemini'),
              'anthropic' => tr('Claude'),
              _ => tr('OpenAI'),
            },
            onChanged: _pickProvider,
          ),
          const SizedBox(height: 8),
          Text(
              switch (_provider) {
                'google' => tr(
                    'Key from Google AI Studio (aistudio.google.com). Has a free tier.'),
                'anthropic' =>
                  tr('Key from the Claude Console (platform.claude.com).'),
                _ => tr('Key from the OpenAI platform (platform.openai.com).'),
              },
              style: UtText.caption),
          const SizedBox(height: 24),
          UtSectionLabel(tr('Model')),
          _Field(
            fieldKey: const ValueKey('ai-model-field'),
            controller: _model,
            hint: defaultJudgeModel(_provider),
          ),
          const SizedBox(height: 6),
          Text(tr('Any model name your provider supports.'),
              style: UtText.caption),
          const SizedBox(height: 24),
          UtSectionLabel(tr('API key'),
              trailing: _keyIsSaved
                  ? UtPill(
                      tr('Saved ••••{hint}', {'hint': _judge.keyHint ?? ''}),
                      tone: UtTone.good)
                  : null),
          _Field(
            fieldKey: const ValueKey('ai-key-field'),
            controller: _key,
            hint: _keyIsSaved
                ? tr('Leave empty to keep the saved key')
                : tr('Paste your API key'),
            obscure: !_showKey,
            suffix: IconButton(
              tooltip: _showKey ? tr('Hide key') : tr('Show key'),
              icon: Icon(
                  _showKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: UtColors.muted),
              onPressed: () => setState(() => _showKey = !_showKey),
            ),
          ),
          const SizedBox(height: 6),
          Text(
              tr('Stored only in this phone’s secure storage (Android Keystore). Never sent to Firebase or your computer.'),
              style: UtText.caption),
          if (status != null) ...[
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerLeft,
                child: UtPill(status.$1, tone: status.$2)),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: UtButton(
                label: _testing ? tr('Testing…') : tr('Test connection'),
                actionName: 'Test connection',
                style: UtButtonStyle.secondary,
                onPressed: _testing ? null : _test,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: UtButton(
                label: _saving ? tr('Saving…') : tr('Save'),
                actionName: 'Save AI settings',
                onPressed: _saving ? null : _save,
              ),
            ),
          ]),
          if (_keyIsSaved) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _remove,
                child: Text(tr('Remove saved key'),
                    style: UtText.caption.copyWith(color: UtColors.orange)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
              tr('A review sends about 6,000 tokens of usage totals and costs a few cents with most models. No prompts or code are sent.'),
              style: UtText.caption),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.fieldKey,
      required this.controller,
      required this.hint,
      this.obscure = false,
      this.suffix});
  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: controller,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        style: UtText.body.copyWith(color: UtColors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: UtText.body,
          filled: true,
          fillColor: UtColors.card,
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: UtColors.cardBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: UtColors.muted)),
        ),
      );
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
                context,
                tr('Copied {n} daily records as {kind}.',
                    {'n': docs.length, 'kind': kind}));
          }
        }

        return UtPage(
          title: tr('Export'),
          subtitle: tr('Copy your usage data for this month.'),
          onBack: () => liveBack(context, '/account'),
          actions: [
            UtButton(
                label: tr('Copy CSV'),
                actionName: 'Download CSV',
                onPressed:
                    docs.isEmpty ? null : () => copy('CSV', toCsv(docs))),
            UtButton(
                label: tr('Copy JSON'),
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
            Text(docs.isEmpty ? tr('Nothing to export') : tr('Ready to export'),
                textAlign: TextAlign.center, style: UtText.title),
            const SizedBox(height: 6),
            Text(
                tr('{n} daily records · {month}',
                    {'n': docs.length, 'month': monthYear(now)}),
                textAlign: TextAlign.center,
                style: UtText.body),
            const SizedBox(height: 28),
            UtCard(
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: MiniStat(
                          value: compact(t.tokens), label: tr('Tokens'))),
                  Expanded(
                      child:
                          MiniStat(value: usd(t.costUsd), label: tr('Cost'))),
                  Expanded(
                      child:
                          MiniStat(value: '${docs.length}', label: tr('Days'))),
                ]),
                const SizedBox(height: 18),
                const UtDivider(),
                const SizedBox(height: 14),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(tr('Provider mix'), style: UtText.label)),
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
      title: tr('Estimated cost'),
      subtitle: tr('{p} · by model', {'p': periodText(period)}),
      onBack: () => liveBack(context, '/tokens'),
      actions: [
        UtButton(
            label: tr('View model pricing'),
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
                      Text(tr('Estimated cost'), style: UtText.label),
                      const SizedBox(height: 8),
                      Text(usdSmart(t.costUsd), style: UtText.code),
                      Text(tr('{n} tokens', {'n': tok(t.tokens)}),
                          style: UtText.caption),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                UtCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: UtRowGroup(children: [
                    if (models.isEmpty)
                      UtRow(title: tr('No usage in this period')),
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
                          title: tr('Total estimated'),
                          trailing: UtValue(usdSmart(t.costUsd))),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                Text(
                    tr('Based on the price catalog saved on your desktop. Final bills from providers may differ.'),
                    style: UtText.caption),
              ],
            );
          },
        ),
      ],
    );
  }
}
