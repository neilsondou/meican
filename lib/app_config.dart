abstract final class AppConfig {
  /// 云同步（Cloudflare Worker）地址。
  static const String apiBase = String.fromEnvironment(
    'MEICAN_API_BASE',
    defaultValue: 'https://api.meican.dou.asia',
  );

  /// 网页 AI 默认走同源的 Vercel Serverless；本地调试时可以覆盖。
  static const String _aiProxyOverride = String.fromEnvironment(
    'MEICAN_AI_PROXY',
  );

  static Uri api(String path) {
    final base = apiBase.endsWith('/')
        ? apiBase.substring(0, apiBase.length - 1)
        : apiBase;
    return Uri.parse('$base$path');
  }

  static Uri get aiProxy {
    if (_aiProxyOverride.isNotEmpty) return Uri.parse(_aiProxyOverride);
    return Uri.base.resolve('api/ai');
  }
}
