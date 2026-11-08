import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_navigation.dart';
import 'package:utoken_mobile/features/auth/presentation/reviewed_state_view.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await loader.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    if (Platform.isWindows) {
      final symbols = FontLoader('Arial');
      symbols.addFont(File('C:/Windows/Fonts/arial.ttf')
          .readAsBytes()
          .then((b) => ByteData.sublistView(b)));
      await symbols.load();
      final extra = FontLoader('Segoe UI Symbol');
      extra.addFont(File('C:/Windows/Fonts/seguisym.ttf')
          .readAsBytes()
          .then((b) => ByteData.sublistView(b)));
      await extra.load();
    }
  });
  testWidgets(
      'M01-M04: 23 real state fixtures match reference anchors and have working actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final states = reviewedStates.entries
        .where((e) => ['M01', 'M02', 'M03', 'M04'].contains(e.key))
        .expand((e) => e.value);
    expect(states.length, 23);
    var actions = 0;
    final tabs = <int>[];
    for (final state in states) {
      final data = await tester
          .runAsync(() => const AuthMockRepository().getStateData(state));
      expect(data!.figmaLayout, isNotNull, reason: state.name);
      final spec = data.figmaLayout!;
      final assets = <String>[
        spec['illustration'],
        spec['divider'],
        ...List<String>.from(spec['dots']),
        ...List<dynamic>.from(spec['nav']).whereType<String>(),
      ];
      for (final path in assets) {
        expect(File(path).lengthSync(), greaterThan(0), reason: path);
      }
      await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: ReviewedStateView(
                data: data,
                onAction: () => actions++,
                onBack: () {},
                onSelectState: () {},
                onTab: tabs.add),
          )));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const ValueKey('reviewed-state-card'))),
          const Rect.fromLTWH(20, 142, 350, 260));
      expect(
          tester.getRect(find.byKey(const ValueKey('reviewed-state-action'))),
          Rect.fromLTWH(20, data.screenId == 'M04' ? 700 : 736, 350, 52));
      await tester.tap(find.byKey(const ValueKey('reviewed-state-action')));
      await tester.pumpAndSettle();
      if (data.screenId == 'M04') {
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(ValueKey('reviewed-state-tab-$i')));
        }
      }
      expect(tester.takeException(), isNull, reason: state.name);
      await saveCapture(tester, state.name);
    }
    expect(actions, 23);
    expect(
        tabs, List.generate(6, (_) => [0, 1, 2, 3]).expand((x) => x).toList());
  });

  testWidgets('M01-M04 and M04B Dark reference canvases render without errors',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final id in ['M01', 'M02', 'M03', 'M04', 'M04B']) {
      await tester.runAsync(() async {
        await FigmaMockRepository.screen(id, Brightness.dark);
        await FigmaMockRepository.hotspots(id);
      });
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark),
        home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: FigmaPixelScreen(screenId: id)),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: id);
      await saveCapture(tester, id);
    }
  });
}

Future<void> saveCapture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/m01-m04-review/rendered')
        ..createSync(recursive: true);
      await File('${dir.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
