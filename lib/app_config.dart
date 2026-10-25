import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class AppConfig {
  /// 云同步与 AI 代理统一部署在 Vercel，网页端走同源接口。
  static const String nativeBase = 'https://meican.dou.asia';
  static const String _apiOverride = String.fromEnvironment('MEICAN_API_BASE');

  static const String iosDownloadUrl = 'https://www.dou.asia/meican.ipa';
  static const String androidDownloadUrl = 'https://www.dou.asia/meican.apk';

  static String get _base {
    if (_apiOverride.isNotEmpty) {
      return _apiOverride.endsWith('/')
          ? _apiOverride.substring(0, _apiOverride.length - 1)
          : _apiOverride;
    }
    return kIsWeb ? '' : nativeBase;
  }

  static Uri api(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    if (_base.isEmpty) return Uri.base.resolve(normalized.substring(1));
    return Uri.parse('$_base$normalized');
  }

  static const String _aiProxyOverride = String.fromEnvironment(
    'MEICAN_AI_PROXY',
  );

  static Uri get aiProxy {
    if (_aiProxyOverride.isNotEmpty) return Uri.parse(_aiProxyOverride);
    return api('api/ai');
  }
}
