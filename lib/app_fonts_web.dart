import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const List<String> _cdnBases = [
  'https://jsd.onmicrosoft.cn/gh/neilsondou/meican@main/assets/fonts/',
  'https://cdn.jsdmirror.com/gh/neilsondou/meican@main/assets/fonts/',
  'https://fastly.jsdelivr.net/gh/neilsondou/meican@main/assets/fonts/',
];

const List<String> _fontFiles = [
  'MeicanSans-Regular.woff2',
  'MeicanSans-SemiBold.woff2',
];

Future<void> loadPlatformFonts() async {
  try {
    final fonts = await Future.wait(_fontFiles.map(_loadFont));
    final loader = FontLoader('MeicanSans');
    var loaded = 0;
    for (final font in fonts) {
      if (font == null) continue;
      loader.addFont(Future<ByteData>.value(font));
      loaded++;
    }
    if (loaded == 0) return;
    await loader.load();
  } catch (_) {
    // 字体加载失败时退回系统字体，不影响功能。
  }
}

Future<ByteData?> _loadFont(String file) async {
  final fromCdn = await _raceCdns(file);
  if (fromCdn != null) return fromCdn;
  try {
    return await rootBundle
        .load('assets/fonts/$file')
        .timeout(const Duration(seconds: 4));
  } catch (_) {
    return null;
  }
}

/// 同时请求所有镜像，谁先返回有效字体就用谁，避免某个 CDN 变慢时排队等待。
Future<ByteData?> _raceCdns(String file) {
  final completer = Completer<ByteData?>();
  var remaining = _cdnBases.length;
  for (final base in _cdnBases) {
    unawaited(() async {
      ByteData? data;
      try {
        data = await _fetchFont(Uri.parse('$base$file'));
      } catch (_) {
        // 这个镜像不可用，等其它镜像或本地回退。
      }
      if (data != null && !completer.isCompleted) completer.complete(data);
      remaining--;
      if (remaining == 0 && !completer.isCompleted) completer.complete(null);
    }());
  }
  return completer.future;
}

Future<ByteData?> _fetchFont(Uri uri) async {
  final response = await http.get(uri).timeout(const Duration(seconds: 4));
  if (response.statusCode != 200 || response.bodyBytes.length <= 10000) {
    return null;
  }
  return ByteData.sublistView(response.bodyBytes);
}
