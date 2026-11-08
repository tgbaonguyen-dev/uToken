import 'package:flutter/widgets.dart';

/// Standalone fixture widgets default to preview; app entry points choose explicitly.
class UiPreviewScope extends InheritedWidget {
  const UiPreviewScope(
      {super.key, required this.enabled, required super.child});
  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiPreviewScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(UiPreviewScope oldWidget) =>
      enabled != oldWidget.enabled;
}
