import 'package:flutter/services.dart';

Future<void> loadPlatformFonts() async {
  try {
    final loader = FontLoader('MeicanSans')
      ..addFont(rootBundle.load('assets/fonts/MeicanSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/MeicanSans-SemiBold.ttf'));
    await loader.load();
  } catch (_) {
    // 字体加载失败时退回系统字体，不影响功能。
  }
}
