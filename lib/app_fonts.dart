import 'app_fonts_io.dart'
    if (dart.library.js_interop) 'app_fonts_web.dart'
    as platform;

/// Web 端从国内可访问的 CDN 加载字体，失败时回退到打包文件；
/// 原生端直接读取本地字体。
Future<void> loadAppFonts() => platform.loadPlatformFonts();
