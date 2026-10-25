abstract final class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'MEICAN_API_BASE',
    defaultValue: 'https://api.meican.dou.asia',
  );

  static Uri api(String path) {
    final base = apiBase.endsWith('/')
        ? apiBase.substring(0, apiBase.length - 1)
        : apiBase;
    return Uri.parse('$base$path');
  }
}
