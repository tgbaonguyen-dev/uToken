import 'package:flutter_test/flutter_test.dart';
import 'package:utoken_mobile/features/figma/presentation/figma_pixel_screen.dart';
import 'package:utoken_mobile/features/onboarding/presentation/onboarding_screens.dart';

const _widgetScreens = {
  WelcomeScreen: 'M01',
  ConnectDesktopScreen: 'M02',
  InstallGuideScreen: 'M03',
};

/// Figma ID of the top-most screen, whether it is drawn by
/// [FigmaPixelScreen] or rebuilt with layout widgets.
String? topScreenId(WidgetTester tester) {
  String? id;
  for (final element in find
      .byWidgetPredicate((w) =>
          w is FigmaPixelScreen || _widgetScreens.containsKey(w.runtimeType))
      .evaluate()) {
    final widget = element.widget;
    id = widget is FigmaPixelScreen
        ? widget.screenId
        : _widgetScreens[widget.runtimeType];
  }
  return id;
}
