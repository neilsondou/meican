import 'dart:math';

/// 构建时通过 --dart-define=MEICAN_AI_KEYS=key1,key2,... 注入。
/// 密钥不写入仓库；未配置时应用会提示识别服务未启用。
abstract final class AiKeyPool {
  static const String _rawKeys = String.fromEnvironment('MEICAN_AI_KEYS');
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
