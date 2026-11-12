import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';
import 'package:utoken_mobile/features/insights/presentation/insight_detail_screen.dart';
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
  testWidgets('Dark main and overlay screens render for visual review',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final id in [
      'M01',
      'M02',
      'M03',
      'M04',
      'M04B',
      'M05',
      'M05B',
      'M05C',
      'M06',
      'M07',
      'M08',
      'M09',
      'M10',
      'M11',
      'M12',
      'M13',
      'O01',
      'O02',
      'O03',
      'M14',
      'M15',
      'S01',
      'S02',
      'S03',
      'S04'
    ]) {
      await tester.runAsync(() async {
        if (id == 'M08') {
          await FigmaMockRepository.insightScreen();
        } else if (FigmaMockRepository.syncScreenIds.contains(id)) {
          await FigmaMockRepository.syncScreen(id, Brightness.dark);
        } else if (FigmaMockRepository.extraScreenIds.contains(id)) {
          await FigmaMockRepository.extraScreen(id, Brightness.dark);
        } else if (id == 'M04') {
          await FigmaMockRepository.tokensScreen(Brightness.dark);
        } else if (FigmaMockRepository.explorerScreenIds.contains(id)) {
          await FigmaMockRepository.usageScreen(id, Brightness.dark);
        } else if (['M09', 'M10', 'M11', 'M12', 'M13'].contains(id)) {
          await FigmaMockRepository.settingsScreen(id, Brightness.dark);
        } else {
          await FigmaMockRepository.screen(id, Brightness.dark);
        }
        final raw = await FigmaMockRepository.screen(id, Brightness.dark);
        for (final layer in raw.layers.where((l) => l['t'] == 'a')) {
          final name =
              (layer['id'] as String).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          expect(File('assets/figma/$name.svg').lengthSync(), greaterThan(0),
              reason: '$id $name');
        }
        await FigmaMockRepository.hotspots(id);
      });
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: id == 'M08'
                ? const InsightDetailScreen()
                : FigmaPixelScreen(key: ValueKey(id), screenId: id)),
      ));
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pumpAndSettle();
      }
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
      final dir = Directory(
          'build/dark-review/${const String.fromEnvironment('CAPTURE_STAGE', defaultValue: 'before')}')
        ..createSync(recursive: true);
      await File('${dir.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
