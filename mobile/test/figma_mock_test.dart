import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/app/figma_routes.dart';
import 'package:utoken_mobile/core/mock/figma_mock_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each primary Figma layer has a valid local asset reference', () async {
    expect(FigmaMockRepository.screenIds.length, 24);
    expect(figmaRoutes.keys.toSet(), FigmaMockRepository.screenIds.toSet());
    for (final id in FigmaMockRepository.screenIds) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final screen = await FigmaMockRepository.screen(id, brightness);
        expect(screen.nodeId, isNotEmpty, reason: id);
        expect(screen.layers.any((layer) => layer['t'] == 't'), isTrue);
        for (final asset in screen.layers.where((l) => l['t'] == 'a')) {
          final nodeId = asset['id'] as String;
          final filename = nodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          final bytes = await rootBundle.load('assets/figma/$filename.svg');
          expect(bytes.lengthInBytes, greaterThan(0), reason: nodeId);
        }
      }
    }
  });

  test('prototype action positions remain valid', () async {
    for (final id in FigmaMockRepository.screenIds) {
      for (final spot in await FigmaMockRepository.hotspots(id)) {
        expect(spot.width, greaterThan(0), reason: spot.name);
        expect(spot.height, greaterThan(0), reason: spot.name);
        expect(spot.x, greaterThanOrEqualTo(0), reason: spot.name);
        expect(spot.y, greaterThanOrEqualTo(0), reason: spot.name);
      }
    }
  });
}
