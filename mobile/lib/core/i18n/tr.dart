import '../data/local_prefs.dart';
import 'vi.dart';

/// Translates an English UI string for the current app language.
/// The English text is the key; `{name}` placeholders are filled from [args].
/// Missing Vietnamese entries fall back to English.
String tr(String en, [Map<String, Object?> args = const {}]) {
  var s = LocalPrefs.instance.vietnamese ? (vi[en] ?? en) : en;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Language name the AI review should write in.
String aiLanguage() =>
    LocalPrefs.instance.vietnamese ? 'Vietnamese' : 'English';
