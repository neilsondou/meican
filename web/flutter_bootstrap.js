{{flutter_js}}
{{flutter_build_config}}

// Vercel 在国内直连约 30 KB/s，首屏的 JS 和 CanvasKit 改由 jsDelivr 国内镜像加载。
// 本地预览直接用本目录资源，避免测试时加载线上旧版本。
const _localPreview = ['localhost', '127.0.0.1'].includes(location.hostname);
// 固定到具体提交，避免 jsDelivr 的 main 分支缓存导致新旧版本混用。
const _staticBase = _localPreview
  ? '/'
  : 'https://cdn.jsdmirror.com/gh/neilsondou/meican-web@c13916cd6de344b6686118dda386a1600f41f99f/';
const _canvasKitBase = _localPreview
  ? 'canvaskit'
  : 'https://cdn.jsdmirror.com/gh/neilsondou/meican-web@c13916cd6de344b6686118dda386a1600f41f99f/canvaskit';

_flutter.loader.load({
  config: {
    entrypointBaseUrl: _staticBase,
    canvasKitBaseUrl: _canvasKitBase,
  },
});
