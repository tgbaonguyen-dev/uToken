import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/figma_routes.dart';
import '../../../core/widgets/figma_viewport.dart';
import '../../../core/widgets/budget_limit_dialog.dart';
import '../../../core/widgets/ui_preview_scope.dart';
import '../../../core/mock/figma_mock_repository.dart';
import '../../auth/presentation/reviewed_state_navigation.dart';
import '../../auth/domain/mobile_auth.dart';
import '../../auth/presentation/mobile_auth_status.dart';

part 'extra_mock_actions.dart';

/// Draws the actual Figma elements, without replacing screens with screenshots.
///
/// The design is 390 Ă— 844. Shapes and SVGs come from Figma, visible copy comes
/// exclusively from mock JSON, and tap targets are exported from PROTO frames.
class FigmaPixelScreen extends StatefulWidget {
  const FigmaPixelScreen(
      {super.key,
      required this.screenId,
      this.initialPeriod = 'Month',
      this.selectedDay,
      this.onBack,
      this.onMarkReviewed});

  final String screenId;
  final String initialPeriod;
  final String? selectedDay;
  final VoidCallback? onBack;
  final VoidCallback? onMarkReviewed;

  @override
  State<FigmaPixelScreen> createState() => _FigmaPixelScreenState();
}

class _FigmaPixelScreenState extends State<FigmaPixelScreen> {
  final _noticeMessengerKey = GlobalKey<ScaffoldMessengerState>();
  Future<FigmaMockScreen>? _screenFuture;
  Future<List<FigmaMockHotspot>>? _hotspotsFuture;
  String? _loadedScreenId;

  @override
  void initState() {
    super.initState();
    _tokensPeriod = _validPeriod(widget.initialPeriod);
    FigmaMockRepository.settingsRevision.addListener(_settingsChanged);
    _hotspotsFuture = FigmaMockRepository.hotspots(widget.screenId);
  }

  Brightness? _loadedBrightness;
  String? _authUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = MobileAuthScope.maybeOf(context)?.user?.uid;
    if (_authUid != uid) {
      _authUid = uid;
      _screenFuture = null;
    }
    _loadScreenIfNeeded(Theme.of(context).brightness);
  }

  @override
  void didUpdateWidget(covariant FigmaPixelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenId != widget.screenId) {
      _tokensPeriod = _validPeriod(widget.initialPeriod);
      _taskSize = 'Medium';
      _grouping = 'Daily';
      _sortBy = 'date';
      _ascending = false;
      _budgetDraft = null;
      _insightReviewed = false;
      _selectedHotspot = null;
      _hotspotsFuture = FigmaMockRepository.hotspots(widget.screenId);
      _loadScreenIfNeeded(_loadedBrightness ?? Brightness.light);
    } else if (oldWidget.initialPeriod != widget.initialPeriod ||
        oldWidget.selectedDay != widget.selectedDay) {
      _tokensPeriod = _validPeriod(widget.initialPeriod);
      _screenFuture = _loadData(_loadedBrightness ?? Brightness.light);
    }
  }

  void _loadScreenIfNeeded(Brightness brightness) {
    if (_screenFuture != null &&
        _loadedScreenId == widget.screenId &&
        _loadedBrightness == brightness) {
      return;
    }
    _loadedScreenId = widget.screenId;
    _loadedBrightness = brightness;
    _screenFuture = _loadData(brightness);
  }

  Future<FigmaMockScreen> _loadData(Brightness brightness) {
    if (FigmaMockRepository.syncScreenIds.contains(widget.screenId)) {
      return FigmaMockRepository.syncScreen(widget.screenId, brightness);
    }
    if (FigmaMockRepository.extraScreenIds.contains(widget.screenId)) {
      return FigmaMockRepository.extraScreen(widget.screenId, brightness);
    }
    if (widget.screenId == 'M08') {
      return FigmaMockRepository.insightScreen(reviewed: _insightReviewed);
    }
    if (_settingsScreens.contains(widget.screenId)) {
      return FigmaMockRepository.settingsScreen(widget.screenId, brightness,
          budgetDraft: _budgetDraft,
          accountName: MobileAuthScope.maybeOf(context)?.user?.displayName,
          accountEmail: MobileAuthScope.maybeOf(context)?.user?.email);
    }
    if (widget.screenId == 'M04') {
      return FigmaMockRepository.tokensScreen(brightness,
          period: _tokensPeriod);
    }
    if (FigmaMockRepository.explorerScreenIds.contains(widget.screenId)) {
      return FigmaMockRepository.usageScreen(widget.screenId, brightness,
          period: _tokensPeriod,
          taskSize: _taskSize,
          grouping: _grouping,
          sortBy: _sortBy,
          selectedDay: widget.selectedDay,
          ascending: _ascending);
    }
    return FigmaMockRepository.screen(widget.screenId, brightness);
  }

  String _validPeriod(String value) =>
      const ['Day', 'Week', 'Month', 'Total'].contains(value) ? value : 'Month';

  String _withPeriod(String route) {
    final uri = Uri.parse(route);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'period': _tokensPeriod
    }).toString();
  }

  static Future<Map<String, dynamic>>? _navigationFuture;

  Future<Map<String, dynamic>> get _navigation =>
      _navigationFuture ??= _loadNavigation();

  static Future<Map<String, dynamic>> _loadNavigation() async {
    final raw = await rootBundle.loadString(
      'lib/core/mock/data/figma_navigation_targets.json',
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String? _selectedHotspot;
  String _tokensPeriod = 'Month';
  String _taskSize = 'Medium';
  String _grouping = 'Daily';
  String _sortBy = 'date';
  bool _ascending = false;
  Map<String, dynamic>? _budgetDraft;
  bool _insightReviewed = false;
  static const _settingsScreens = ['M09', 'M10', 'M11', 'M12', 'M13'];

  void _settingsChanged() {
    if (mounted) {
      setState(() {
        _screenFuture =
            _loadData(_loadedBrightness ?? Theme.of(context).brightness);
      });
    }
  }

  @override
  void dispose() {
    FigmaMockRepository.settingsRevision.removeListener(_settingsChanged);
    super.dispose();
  }

  Future<bool> _confirmMock(String title, String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                scrollable: true,
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Confirm demo')),
                ],
              )) ??
      false;

  Future<bool> _handleSettingsHotspot(String name) async {
    if (!_settingsScreens.contains(widget.screenId)) return false;
    final data = await FigmaMockRepository.settingsData();
    if (!mounted) return true;
    if (widget.screenId == 'M09') {
      const keys = {
        'Language': 'language',
        'Token numbers': 'numberFormat',
        'Sync interval': 'syncInterval'
      };
      final key = keys[name];
      if (key == null) return false;
      final options = await FigmaMockRepository.settingsOptions(key);
      if (!mounted) return true;
      final value = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
            child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
                title: Text(name),
                subtitle: Text(key == 'language'
                    ? 'Mock preference only. Preview text remains English.'
                    : 'Mock preference / this session only')),
            for (final option in options)
              ListTile(
                  title: Text(option),
                  trailing:
                      data[key] == option ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheetContext, option)),
          ],
        )),
      );
      if (value != null) await FigmaMockRepository.updateSettings({key: value});
      return true;
    }
    if (widget.screenId == 'M11') {
      _budgetDraft ??= {
        for (final key in ['monthlyLimit', 'alert90', 'alert100'])
          key: data[key]
      };
      if (name == '90% alert' || name == '100% alert') {
        final key = name == '90% alert' ? 'alert90' : 'alert100';
        _budgetDraft![key] = !(_budgetDraft![key] as bool);
        _settingsChanged();
        return true;
      }
      if (name == 'Edit monthly limit') {
        final value = await showDialog<double>(
          context: context,
          builder: (_) => BudgetLimitDialog(
              initialAmount: _budgetDraft!['monthlyLimit'] as num),
        );
        if (!mounted) return true;
        if (value != null) {
          _budgetDraft!['monthlyLimit'] = value;
          _settingsChanged();
        }
        return true;
      }
      if (name == 'Save budget') {
        await FigmaMockRepository.updateSettings(_budgetDraft!);
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/settings');
          }
        }
        return true;
      }
    }
    if (widget.screenId == 'M10') {
      if (name == 'Background sync') {
        await FigmaMockRepository.updateSettings(
            {'backgroundSync': !(data['backgroundSync'] as bool)});
        return true;
      }
      if (name == 'Disconnect this computer') {
        final connected = data['connected'] as bool;
        if (await _confirmMock(
            connected
                ? 'Disconnect demo computer?'
                : 'Reconnect demo computer?',
            'Changes the mock connection for this session only.')) {
          await FigmaMockRepository.updateSettings({'connected': !connected});
        }
        return true;
      }
      if (name == 'Sync now') {
        if (data['connected'] != true) {
          _showNotice('Reconnect the demo computer first.');
          return true;
        }
        await FigmaMockRepository.updateSettings({'lastSync': 'Just now'});
        return false;
      }
    }
    if (widget.screenId == 'M12' && name == 'Diagnostics') {
      await FigmaMockRepository.updateSettings(
          {'diagnostics': !(data['diagnostics'] as bool)});
      return true;
    }
    if ((widget.screenId == 'M12' && name == 'Delete data') ||
        (widget.screenId == 'M13' && name == 'Delete account')) {
      if (await _confirmMock('$name (demo)?',
          'Simulates the confirmation flow. No real account, data or mock fixtures will be removed.')) {
        if (mounted) {
          _showNotice('Demo request completed. No data was removed.');
        }
      }
      return true;
    }
    if (widget.screenId == 'M13' && name == 'Google account') {
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                scrollable: true,
                title: const Text('Google account (mock)'),
                content: Text(
                    '${data['accountName']}\n${data['accountEmail']}\n\nNo real Google session is connected in this preview.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'))
                ],
              ));
      return true;
    }
    return false;
  }

  void _showNotice(String message) {
    if (message.isEmpty || !mounted) return;
    final messenger = _noticeMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
            left: 16, right: 16, bottom: _hasBottomBar ? 88 : 16),
      ),
    );
  }

  bool _handlingAction = false;

  Future<void> _handleHotspot(String name) async {
    if (_handlingAction) return;
    _handlingAction = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await _runHotspot(name);
    } finally {
      _handlingAction = false;
    }
  }

  Future<void> _runHotspot(String name) async {
    final auth = MobileAuthScope.maybeOf(context);
    if (auth != null) {
      if (widget.screenId == 'M04' && name == 'Refresh') {
        final refreshed =
            _loadData(_loadedBrightness ?? Theme.of(context).brightness);
        setState(() {
          _screenFuture = refreshed;
        });
        try {
          await refreshed;
          if (mounted) _showNotice('Sample usage refreshed.');
        } catch (_) {
          if (mounted) {
            _showNotice('Could not refresh sample usage. Try again.');
          }
        }
        return;
      }
      if (widget.screenId == 'M02' &&
          (name == 'Back' ||
              name == 'Pair complete' ||
              name == 'Iâ€™ve paired my device' ||
              name == 'I?ve paired my device')) {
        auth.leaveDesktopSetup();
        if (name == 'Back') {
          context.go(_withPeriod('/tokens'));
        } else {
          context.go(_withPeriod('/waiting-first-usage'));
        }
        return;
      }
      if (widget.screenId == 'M01' && name == 'Continue with Google') {
        await auth.signIn();
        return;
      }
      if (widget.screenId == 'M01' && name == 'View demo') {
        auth.enterDemo();
        context.go('/tokens');
        return;
      }
      if (name == 'Sign out') {
        if (auth.demoMode) {
          auth.exitDemo();
          context.go('/welcome');
          return;
        }
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                    scrollable: true,
                    title: const Text('Sign out?'),
                    content: const Text(
                        'You can sign in again with your Google account.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Sign out')),
                    ]));
        if (confirmed == true && mounted) await auth.signOut();
        return;
      }
      if (widget.screenId == 'M13' && name == 'Google account') {
        final user = auth.user;
        await showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
                    scrollable: true,
                    title: const Text('Google account'),
                    content: Text(
                        '${user?.displayName ?? ''}\n${user?.email ?? ''}'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog),
                          child: const Text('Close'))
                    ]));
        return;
      }
    }
    if (widget.screenId == 'S03' && name == 'Complete demo sync') {
      await FigmaMockRepository.updateSettings({'lastSync': 'Just now'});
      if (mounted) context.go(_withPeriod('/tokens'));
      return;
    }
    if (widget.screenId == 'M11' && name == 'Preview budget alert') {
      context.push('/budget-alert');
      return;
    }
    if (await _handleExtraHotspot(name)) return;
    if (!mounted) return;
    if (name == 'Back' && widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (widget.screenId == 'M08' && name == 'Mark reviewed') {
      if (!_insightReviewed) {
        widget.onMarkReviewed?.call();
        setState(() {
          _insightReviewed = true;
          _screenFuture = FigmaMockRepository.insightScreen(reviewed: true);
        });
      }
      return;
    }
    if (widget.screenId == 'M08' &&
        name == 'Back' &&
        GoRouter.maybeOf(context) == null) {
      Navigator.of(context).maybePop();
      return;
    }
    if (await _handleSettingsHotspot(name)) return;
    if (!mounted) return;
    final periodFilter = const ['M04', 'M05'].contains(widget.screenId) &&
        const ['Day', 'Week', 'Month', 'Total'].contains(name);
    final sizeFilter = widget.screenId == 'M05C' &&
        const ['Small', 'Medium', 'Large'].contains(name);
    final groupFilter =
        widget.screenId == 'M06' && const ['Daily', 'Project'].contains(name);
    const sortKeys = {
      'Sort date': 'date',
      'Sort tokens': 'tokens',
      'Sort chats': 'chats'
    };
    final sortFilter = widget.screenId == 'M06' && sortKeys.containsKey(name);
    if (periodFilter || sizeFilter || groupFilter || sortFilter) {
      setState(() {
        if (periodFilter) _tokensPeriod = name;
        if (sizeFilter) _taskSize = name;
        if (groupFilter && name != _grouping) {
          _grouping = name;
          _sortBy = 'date';
          _ascending = name == 'Project';
        }
        if (sortFilter) {
          final key = sortKeys[name]!;
          _ascending = key == _sortBy ? !_ascending : false;
          _sortBy = key;
        }
        _screenFuture =
            _loadData(_loadedBrightness ?? Theme.of(context).brightness);
      });
      return;
    }
    final demo = await FigmaMockRepository.demoInteractions();
    if (!mounted) return;

    final allActions = demo['actions'];
    final currentActions =
        allActions is Map ? allActions[widget.screenId] : null;
    final action = currentActions is Map ? currentActions[name] : null;
    if (action is Map) {
      final message = action['message']?.toString() ?? '';
      switch (action['type']?.toString()) {
        case 'route':
          final target = action['target']?.toString();
          final route = action['path']?.toString() ??
              (target == null ? null : figmaPathFor(target));
          if (route != null) {
            context.push(_withPeriod(route));
            return;
          }
        case 'select':
          setState(() => _selectedHotspot = name);
          _showNotice(message);
          return;
        case 'copy':
          await Clipboard.setData(
            ClipboardData(text: action['value']?.toString() ?? ''),
          );
          if (mounted) _showNotice(message);
          return;
        case 'notice':
          _showNotice(message);
          return;
      }
    }

    final nav = await _navigation;
    if (!mounted) return;
    if (name == 'Back' || name == 'Close' || name == 'Dismiss') {
      if (context.canPop()) {
        context.pop();
        return;
      }
    }

    final targets = nav['routes'] as Map<String, dynamic>;
    final screenTargets = targets[widget.screenId] as Map<String, dynamic>?;
    final target = screenTargets?[name]?.toString();
    if (target == null) {
      _showNotice(demo['fallbackMessage']?.toString() ?? '');
      return;
    }
    if (target == '@pop') {
      if (context.canPop()) {
        context.pop();
      } else if (widget.screenId == 'O03') {
        context.go('/tokens');
      }
      return;
    }
    final route = figmaPathFor(target);
    if (route == null) return;
    if (name == 'Sign out' ||
        name == 'Back' ||
        name == 'Close' ||
        name == 'Dismiss') {
      context.go(_withPeriod(route));
    } else {
      context.push(_withPeriod(route));
    }
  }

  Future<void> _openScreenGallery() async {
    // FigmaMockRepository owns the complete 24-frame manifest.
    // The sheet is synchronous; it never stalls while waiting for assets.
    final ids = FigmaMockRepository.screenIds.toList(growable: false);
    final origin = context;
    await showModalBottomSheet<void>(
      context: origin,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            children: [
              const ListTile(
                title: Text('All 25 Figma screens'),
                subtitle: Text(
                    'Includes insight detail and state previews from both branches'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (reviewedStates.containsKey(widget.screenId))
                        ListTile(
                          title: Text('${widget.screenId} - UI states'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            showReviewedStates(origin, widget.screenId,
                                period: _tokensPeriod);
                          },
                        ),
                      for (final entry in supplementalUiRoutes.entries)
                        ListTile(
                          title: Text(entry.key),
                          subtitle: Text(entry.value),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            if (mounted) origin.push(entry.value);
                          },
                        ),
                      for (final id in ids)
                        ListTile(
                          title: Text(id),
                          subtitle: Text(figmaPathFor(id) ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          selected: id == widget.screenId,
                          onTap: () {
                            final path = figmaPathFor(id);
                            Navigator.of(sheetContext).pop();
                            if (path != null && mounted) origin.go(path);
                          },
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

  void _onBottomTap(int tabIndex) {
    const tabScreenIds = ['M04', 'M05', 'M07', 'M09'];
    if (tabIndex < 0 || tabIndex >= tabScreenIds.length) return;
    final route = figmaPathFor(tabScreenIds[tabIndex]);
    if (route == null) return;
    if (GoRouter.maybeOf(context) != null) {
      context.go(_withPeriod(route));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => FigmaPixelScreen(
              screenId: tabScreenIds[tabIndex], initialPeriod: _tokensPeriod)));
    }
  }

  bool get _hasBottomBar => const [
        'M04',
        'M05',
        'M07',
        'M08',
        'M09',
        'S01',
        'S02',
        'S03',
        'S04',
      ].contains(widget.screenId);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final pageBackground =
        brightness == Brightness.dark ? const Color(0xFF080A0D) : Colors.white;

    final router = GoRouter.maybeOf(context);
    final hasBack = const [
      'M02',
      'M03',
      'M04B',
      'M05B',
      'M05C',
      'M06',
      'M08',
      'M10',
      'M11',
      'M12',
      'M13',
      'M14',
      'M15',
      'O01',
      'O02',
      'O03'
    ].contains(widget.screenId);
    return MobileAuthStatus(
        child: ScaffoldMessenger(
            key: _noticeMessengerKey,
            child: PopScope(
                canPop: router == null || router.canPop() || !hasBack,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    _handleHotspot(
                        widget.screenId == 'O03' ? 'Dismiss' : 'Back');
                  }
                },
                child: Scaffold(
                  backgroundColor: pageBackground,
                  body: FutureBuilder<FigmaMockScreen>(
                    future: _screenFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              snapshot.error.toString(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.expand();
                      }
                      final screen = snapshot.data!;
                      return FigmaViewport(
                        width: screen.width,
                        height: screen.height,
                        footerBuilder: _hasBottomBar
                            ? (scale) => _bottomDock(screen, scale)
                            : null,
                        builder: (scale) => SizedBox(
                          width: screen.width * scale,
                          height: screen.height * scale,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: FittedBox(
                                  fit: BoxFit.fill,
                                  child: SizedBox(
                                    width: screen.width,
                                    height: screen.height,
                                    child: _buildFigmaCanvas(context, screen),
                                  ),
                                ),
                              ),
                              // Preview-only index: accessible without changing the
                              // original Figma appearance (hold any screen title).
                              if (UiPreviewScope.enabledOf(context))
                                Positioned(
                                  left: 78 * scale,
                                  top: 38 * scale,
                                  width: 234 * scale,
                                  height: 62 * scale,
                                  child: GestureDetector(
                                    key: const ValueKey(
                                        'figma-screen-gallery-trigger'),
                                    behavior: HitTestBehavior.translucent,
                                    onLongPress: _openScreenGallery,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ))));
  }

  Widget _bottomDock(FigmaMockScreen screen, double scale) => ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28 * scale)),
      child: Stack(children: [
        Positioned.fill(
            child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                    width: screen.width,
                    height: 68,
                    child: Stack(children: [
                      const Positioned.fill(
                          child: ColoredBox(color: Color(0xff0c0f13))),
                      ...screen.layers
                          .where((layer) => _number(layer['y']) >= 776)
                          .map((layer) => _paintLayer(
                              {...layer, 'y': _number(layer['y']) - 776})),
                    ])))),
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < 4; i++)
            Expanded(
                child: Semantics(
                    label: ['Tokens', 'Analytics', 'Insights', 'Settings'][i],
                    button: true,
                    selected:
                        ['M04', 'M05', 'M07', 'M09'][i] == widget.screenId,
                    child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                            key: ValueKey('utoken-tab-$i'),
                            onTap: () => _onBottomTap(i),
                            child: const SizedBox.expand())))),
        ]),
      ]));

  Widget _buildFigmaCanvas(
    BuildContext context,
    FigmaMockScreen screen,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        widget.screenId == 'M01' ? 24 : 28,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ..._canvasLayers(screen)
              .where((layer) => !_hasBottomBar || _number(layer['y']) < 776)
              .map(_paintLayer),
          if (widget.screenId == 'M13' &&
              MobileAuthScope.maybeOf(context)?.user?.photoUrl != null)
            Positioned(
                left: 36,
                top: 180,
                width: 46,
                height: 46,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                        MobileAuthScope.maybeOf(context)!.user!.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                            color: const Color(0xfff2f3f5),
                            child: Center(
                                child: Text(
                                    String.fromCharCode(
                                        MobileAuthScope.maybeOf(context)!
                                            .user!
                                            .displayName
                                            .runes
                                            .first),
                                    style:
                                        const TextStyle(color: Color(0xff080a0d)))))))),
          if (widget.screenId == 'S03')
            Positioned(
                left: 60,
                top: 700,
                width: 270,
                height: 44,
                child: OutlinedButton(
                  key: const ValueKey('mock-complete-sync'),
                  onPressed: () => _handleHotspot('Complete demo sync'),
                  child: const Text('Complete demo sync',
                      style:
                          TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12)),
                )),
          if (widget.screenId == 'M11' && UiPreviewScope.enabledOf(context))
            Positioned(
                left: 326,
                top: 42,
                width: 44,
                height: 44,
                child: IconButton(
                    key: const ValueKey('mock-budget-alert-preview'),
                    tooltip: 'Preview budget alert (mock)',
                    icon: const Icon(Icons.notifications_outlined, size: 22),
                    onPressed: () => _handleHotspot('Preview budget alert'))),
          FutureBuilder<List<FigmaMockHotspot>>(
            future: _hotspotsFuture,
            builder: (context, snapshot) {
              final spots = snapshot.data;
              if (spots == null) return const SizedBox.shrink();
              return Stack(
                children: [
                  for (final spot in spots)
                    Positioned.fromRect(
                      rect: _hotspotRect(spot, screen),
                      child: Semantics(
                          label: spot.name,
                          button: true,
                          child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: ValueKey('figma-hotspot-${spot.name}'),
                                borderRadius: spot.radius > 0
                                    ? BorderRadius.circular(spot.radius)
                                    : null,
                                hoverColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                                highlightColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08),
                                splashColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : Colors.black.withValues(alpha: 0.10),
                                onTap: () => _handleHotspot(spot.name),
                                child: const SizedBox.expand(),
                              ))),
                    ),
                  for (final spot in spots)
                    if (_selectedHotspot == spot.name)
                      Positioned.fromRect(
                        rect: _hotspotRect(spot, screen),
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                spot.radius > 0 ? spot.radius : 10,
                              ),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Hover/tap bounds for text controls are measured from the rendered text,
  // not from the larger Figma text-frame. A small, balanced inset keeps the
  // hover surface comfortable without making it look detached from the text.
  Rect _hotspotRect(FigmaMockHotspot spot, FigmaMockScreen screen) {
    final bool isEstimatedCost =
        widget.screenId == 'M04' && spot.name == 'Open cost breakdown';
    final bool isBackControl = spot.name.trim().toLowerCase() == 'back';
    if (!isEstimatedCost && !isBackControl) {
      return Rect.fromLTWH(spot.x, spot.y, spot.width, spot.height);
    }

    final textLayers = screen.layers
        .where((item) => item['t'] == 't')
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
    final layer = isEstimatedCost
        ? textLayers.firstWhere(
            (item) => (item['v']?.toString() ?? '')
                .toLowerCase()
                .contains('estimated'),
            orElse: () => <String, dynamic>{},
          )
        : textLayers.where((item) {
              final x = _number(item['x']);
              final y = _number(item['y']);
              final w = _number(item['w']);
              final h = _number(item['h']);
              final centerX = x + w / 2;
              final centerY = y + h / 2;
              // Back chevrons live in the leading edge of the page header.
              // Limit candidates to the header and the leading 64 logical px.
              return centerX >= 0 &&
                  centerX <= 64 &&
                  centerY >= 20 &&
                  centerY <= 110 &&
                  w > 0 &&
                  h > 0;
            }).fold<Map<String, dynamic>?>(null, (best, candidate) {
              if (best == null) return candidate;
              double distance(Map<String, dynamic> item) {
                final cx = _number(item['x']) + _number(item['w']) / 2;
                final cy = _number(item['y']) + _number(item['h']) / 2;
                final targetX = spot.x + spot.width / 2;
                final targetY = spot.y + spot.height / 2;
                return (cx - targetX) * (cx - targetX) +
                    (cy - targetY) * (cy - targetY);
              }

              return distance(candidate) < distance(best) ? candidate : best;
            }) ??
            <String, dynamic>{};
    if (layer.isEmpty) {
      return Rect.fromLTWH(spot.x, spot.y, spot.width, spot.height);
    }

    final value = layer['v']?.toString() ?? '';
    final fontSize = _number(layer['sz'], fallback: 13);
    final weightName = layer['fw']?.toString() ?? 'Regular';
    final weight = switch (weightName) {
      'Medium' => FontWeight.w500,
      'SemiBold' || 'Semi Bold' => FontWeight.w600,
      'Bold' => FontWeight.w700,
      _ => FontWeight.w400,
    };
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontFamilyFallback: const ['Arial', 'Roboto', 'Segoe UI Symbol'],
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: _number(layer['sp']),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    // 5 px horizontally and 4 px vertically (10 ? 8 total) gives a close,
    // even breathing space around the glyphs while remaining easy to target.
    const horizontalPadding = 10.0;
    const verticalPadding = 4.0;
    final layerX = _number(layer['x']);
    final layerY = _number(layer['y']);
    final layerWidth = _number(layer['w']);
    final layerHeight = _number(layer['h']);
    final alignment = layer['al']?.toString() ?? 'LEFT';
    final textLeft = switch (alignment) {
      'CENTER' => layerX + (layerWidth - painter.width) / 2,
      'RIGHT' => layerX + layerWidth - painter.width,
      _ => layerX,
    };
    final textTop =
        layerY + (layerHeight - painter.height).clamp(0, layerHeight) / 2;
    final width = painter.width + horizontalPadding * 2;
    final height = painter.height + verticalPadding * 2;
    return Rect.fromLTWH(
      textLeft - horizontalPadding,
      textTop - verticalPadding,
      width,
      height,
    );
  }

  List<Map<String, dynamic>> _canvasLayers(FigmaMockScreen screen) {
    final layers = screen.layers;
    if (widget.screenId == 'M04' &&
        layers.length > 8 &&
        layers[8]['t'] == 'r') {
      return [
        ...layers.sublist(0, 6),
        layers[8],
        layers[6],
        layers[7],
        ...layers.sublist(9),
      ];
    }
    return layers;
  }

  Widget _paintLayer(Map<String, dynamic> layer) {
    final left = _number(layer['x']);
    final top = _number(layer['y']);
    final width = _number(layer['w']);
    final height = _number(layer['h']);
    if (width <= 0 || height <= 0) return const SizedBox.shrink();

    late final Widget child;
    switch (layer['t']) {
      case 'p':
        child = CircularProgressIndicator(
          value: _number(layer['progress']),
          color: _color(layer['b']),
          strokeWidth: _number(layer['bw'], fallback: 8),
          strokeAlign: -1,
          trackGap: 0,
          padding: EdgeInsets.zero,
        );
      case 't':
        child = _text(layer);
      case 'a':
        final assetId = layer['id']?.toString() ?? '';
        final fileName = assetId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        child = SvgPicture.asset(
          'assets/figma/$fileName.svg',
          fit: BoxFit.fill,
          placeholderBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      case 'e':
      case 'r':
        child = _shape(layer);
      default:
        child = const SizedBox.shrink();
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: child,
    );
  }

  Widget _shape(Map<String, dynamic> layer) {
    final fill = _color(layer['c']);
    final stroke = _color(layer['b']);
    final border = stroke == null
        ? null
        : Border.all(color: stroke, width: _number(layer['bw'], fallback: 1));

    final isOval = layer['t'] == 'e';
    BorderRadiusGeometry? radius;
    final radii = layer['rs'];
    if (!isOval && radii is List && radii.length == 4) {
      radius = BorderRadius.only(
        topLeft: Radius.circular(_number(radii[0])),
        topRight: Radius.circular(_number(radii[1])),
        bottomRight: Radius.circular(_number(radii[2])),
        bottomLeft: Radius.circular(_number(radii[3])),
      );
    } else if (isOval) {
      radius = BorderRadius.all(
          Radius.elliptical(_number(layer['w']) / 2, _number(layer['h']) / 2));
    } else {
      radius = BorderRadius.circular(_number(layer['rad']));
    }

    List<BoxShadow>? shadow;
    if (layer['shadow'] is Map) {
      final data = layer['shadow'] as Map;
      shadow = [
        BoxShadow(
          color: _color(data['c']) ?? Colors.transparent,
          offset: Offset(_number(data['x']), _number(data['y'])),
          blurRadius: _number(data['blur']),
        ),
      ];
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: fill,
        border: border,
        borderRadius: radius,
        boxShadow: shadow,
      ),
    );
  }

  Widget _text(Map<String, dynamic> layer) {
    final fontSize = _number(layer['sz'], fallback: 13);
    final lineHeight = _number(layer['lh']);
    final styleName = layer['fw']?.toString() ?? 'Regular';
    final weight = switch (styleName) {
      'Thin' => FontWeight.w100,
      'ExtraLight' => FontWeight.w200,
      'Light' => FontWeight.w300,
      'Medium' => FontWeight.w500,
      'SemiBold' || 'Semi Bold' => FontWeight.w600,
      'Bold' => FontWeight.w700,
      'ExtraBold' => FontWeight.w800,
      'Black' => FontWeight.w900,
      _ => FontWeight.w400,
    };
    final alignment = switch (layer['al']) {
      'CENTER' => TextAlign.center,
      'RIGHT' => TextAlign.right,
      'JUSTIFIED' => TextAlign.justify,
      _ => TextAlign.left,
    };
    final verticalAlignment = switch (layer['va']) {
      'CENTER' => Alignment.center,
      'BOTTOM' => Alignment.bottomCenter,
      _ => Alignment.topCenter,
    };

    final fit = layer['fit'] == 'scaleDown';
    final text = Text(
      layer['v']?.toString() ?? '',
      textAlign: alignment,
      softWrap: !fit,
      maxLines: fit ? 1 : null,
      overflow: TextOverflow.visible,
      style: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontFamilyFallback: const ['Arial', 'Roboto', 'Segoe UI Symbol'],
        fontWeight: weight,
        fontSize: fontSize,
        height: lineHeight > 0 ? lineHeight / fontSize : null,
        letterSpacing: _number(layer['sp']),
        color: _color(layer['c']) ?? Colors.black,
        decoration: TextDecoration.none,
      ),
    );
    return Align(
      alignment: verticalAlignment,
      child: SizedBox.expand(
        child: fit
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: switch (alignment) {
                  TextAlign.right => Alignment.topRight,
                  TextAlign.center => Alignment.topCenter,
                  _ => Alignment.topLeft,
                },
                child: text)
            : text,
      ),
    );
  }

  static double _number(dynamic value, {double fallback = 0}) =>
      value is num ? value.toDouble() : fallback;

  static Color? _color(dynamic value) {
    if (value is! String || !value.startsWith('#')) return null;
    final hex = value.substring(1);
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    if (hex.length == 6) return Color(0xFF000000 | int.parse(hex, radix: 16));
    return null;
  }
}
