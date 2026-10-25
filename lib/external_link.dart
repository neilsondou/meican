import 'external_link_io.dart'
    if (dart.library.js_interop) 'external_link_web.dart'
    as platform;

Future<void> openExternalLink(String url) => platform.openExternalLink(url);
