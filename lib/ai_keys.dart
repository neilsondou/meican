import 'dart:math';

/// 优先读取 --dart-define=MEICAN_AI_KEYS=key1,key2,...，未注入时使用内置的
/// ChatGLM 免费测试密钥。密钥会出现在公开仓库中，可能被他人使用，失效后轮换即可。
abstract final class AiKeyPool {
  static const String _rawKeys = String.fromEnvironment(
    'MEICAN_AI_KEYS',
    defaultValue:
        'fd703d86369741f2ad0da6ff0a0b64bf.1Dyloh3jELqb8DzQ,'
        '11c27f2d7be14788862f7fb64472ac8a.YxTpqkSfFb8IoMLE,'
        '4a6c00e8679c4c98a9912e9f8a0e7ed5.ID4UMmNDYJ0JlqFN,'
        'ae1106ec1c9d49128eaf0c04b8d30209.maLRTAG7bqrVaycU',
  );
  static final List<String> _keys = _parse(_rawKeys);
  static final Random _random = Random();
  static int? _cursor;

  static bool get isConfigured => _keys.isNotEmpty;

  /// 每次请求从随机位置开始轮转，正常情况只用一把密钥，失败时才顺延。
  static List<String> nextOrder() {
    if (_keys.isEmpty) return const [];
    final start = _cursor ??= _random.nextInt(_keys.length);
    _cursor = (start + 1) % _keys.length;
    return [
      for (var offset = 0; offset < _keys.length; offset++)
        _keys[(start + offset) % _keys.length],
    ];
  }

  static List<String> _parse(String raw) {
    return raw
        .split(RegExp(r'[\s,;]+'))
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
