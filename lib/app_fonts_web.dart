import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// 按顺序尝试，谁先成功就用谁；不并发请求，避免慢速网络下同时下载三份字体。
const List<String> _cdnBases = [
  'https://cdn.jsdmirror.com/gh/neilsondou/meican@main/assets/fonts/',
  'https://jsd.onmicrosoft.cn/gh/neilsondou/meican@main/assets/fonts/',
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
  for (final base in _cdnBases) {
    try {
      final data = await _fetchFont(
        Uri.parse('$base$file'),
      ).timeout(const Duration(seconds: 6));
      if (data != null) return data;
    } catch (_) {
      // 换下一个镜像。
    }
  }
  try {
    return await rootBundle
        .load('assets/fonts/$file')
        .timeout(const Duration(seconds: 4));
  } catch (_) {
    return null;
  }
}

Future<ByteData?> _fetchFont(Uri uri) async {
  final response = await http.get(uri).timeout(const Duration(seconds: 6));
  if (response.statusCode != 200 || response.bodyBytes.length <= 10000) {
    return null;
  }
  return ByteData.sublistView(response.bodyBytes);
}
