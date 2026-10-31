import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the real fonts a golden render needs so it matches what the app
/// actually ships, instead of falling back to the test harness's tofu-box
/// placeholder glyphs.
///
/// Two sources:
/// - the bundled Noto Sans Arabic weights, loaded as a pubspec asset;
/// - MaterialIcons (every `Icon(Icons.*)` in the app), which isn't a pubspec
///   asset — it ships inside the Flutter SDK cache itself — so it's read
///   straight off disk relative to the running `flutter_tester` executable.
///   Real (non-mocked) file I/O only resolves inside `tester.runAsync` —
///   `testWidgets` otherwise runs in a fake-async zone that never pumps a
///   genuine OS read, so this hangs forever without it.
Future<void> loadAppFonts(WidgetTester tester) async {
  final ibmLoader = FontLoader('IBMPlexSansArabic');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    ibmLoader.addFont(
      rootBundle.load('assets/fonts/IBMPlexSansArabic-$weight.ttf'),
    );
  }
  await ibmLoader.load();
  final notoLoader = FontLoader('NotoSansArabic');
  notoLoader.addFont(
    rootBundle.load('assets/fonts/NotoSansArabic-VariableFont.ttf'),
  );
  await notoLoader.load();

  final materialIconsFont = File(
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  final fontBytes = await tester.runAsync(() async {
    if (!materialIconsFont.existsSync()) return null;
    return materialIconsFont.readAsBytes();
  });
  if (fontBytes != null) {
    final iconsLoader = FontLoader('MaterialIcons');
    iconsLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
    await iconsLoader.load();
  }
}
