import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'app_fonts.dart';
import 'app_state.dart';
import 'cloud_sync.dart';
import 'external_link.dart';
import 'ui/ai_page.dart';
import 'ui/components.dart';
import 'ui/home_page.dart';
import 'ui/progress_page.dart';
import 'ui/record_page.dart';
import 'ui/settings_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  SystemChrome.setSystemUIOverlayStyle(appSystemOverlay);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  runApp(MeiCanApp(state: state, cloud: CloudSync(state)));
}

class MeiCanApp extends StatefulWidget {
  MeiCanApp({super.key, required this.state, CloudSync? cloud})
    : cloud = cloud ?? CloudSync(state);

  final AppState state;
  final CloudSync cloud;

  @override
  State<MeiCanApp> createState() => _MeiCanAppState();
}

class _MeiCanAppState extends State<MeiCanApp> with WidgetsBindingObserver {
  bool _fontsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.state.ready) {
      unawaited(widget.cloud.syncNow());
    }
  }

  Future<void> _boot() async {
    final fonts = loadAppFonts();
    unawaited(
      fonts.whenComplete(() {
        if (mounted) setState(() {});
      }),
    );
    await Future.wait<void>([
      widget.state.load(),
      if (kIsWeb)
        fonts.timeout(const Duration(seconds: 7), onTimeout: () {})
      else
        fonts,
    ]);
    if (mounted) setState(() => _fontsReady = true);
    await widget.cloud.init();
    unawaited(widget.cloud.syncOnLaunch());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '每餐',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: appSystemOverlay,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'MeicanSans',
            color: AppColors.ink,
            decoration: TextDecoration.none,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: _Root(
        state: widget.state,
        cloud: widget.cloud,
        fontsReady: _fontsReady,
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root({
    required this.state,
    required this.cloud,
    required this.fontsReady,
  });

  final AppState state;
  final CloudSync cloud;
  final bool fontsReady;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: state.ready && fontsReady
              ? AppShell(
                  key: const ValueKey('shell'),
                  state: state,
                  cloud: cloud,
                )
              : LaunchView(
                  key: const ValueKey('launch'),
                  showLabel: fontsReady,
                ),
        );
      },
    );
  }
}

class LaunchView extends StatelessWidget {
  const LaunchView({super.key, this.showLabel = true});

  /// 字体尚未注册时先不渲染中文，避免触发 Google Fonts 中文回退字体下载。
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLabel) ...[
                  const Text(
                    '加载中',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      color: AppColors.tertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: 108,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      color: AppColors.accent,
                      backgroundColor: Color(0x24F5F5F7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state, required this.cloud});

  final AppState state;
  final CloudSync cloud;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String _webStorageNoticeKey = 'meican_web_storage_notice_v2';

  int index = 0;
  late final PageController _pageController = PageController(
    initialPage: index,
  );

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWebStorageNotice();
      });
    }
  }

  Future<void> _showWebStorageNotice() async {
    final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    if (preferences.getBool(_webStorageNoticeKey) ?? false) return;
    if (!mounted) return;
    await preferences.setBool(_webStorageNoticeKey, true);
    if (!mounted) return;
    await showAppAlert(
      context,
      title: '数据保存在本地',
      message:
          '网页版的记录保存在当前浏览器中，请不要清理浏览器缓存，也不要使用无痕模式。\n\n'
          '需要跨设备备份时，可以在「我的」里的「云同步」中自愿登录；不开启云同步也能正常使用全部本地功能。',
      extra: const _WebDownloadLinks(),
    );
  }

  void select(int value) {
    if (value == index) return;
    HapticFeedback.selectionClick();
    setState(() => index = value);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(value);
    } else {
      _pageController.animateToPage(
        value,
        duration: const Duration(milliseconds: 380),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  void openCamera() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AiCapturePage(state: widget.state),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: AnimatedBuilder(
                  animation: widget.state,
                  builder: (context, _) {
                    return PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _KeepAlivePage(
                          child: HomePage(
                            state: widget.state,
                            onCamera: openCamera,
                            onOpenRecord: () => select(1),
                            onOpenProgress: () => select(2),
                          ),
                        ),
                        _KeepAlivePage(
                          child: RecordPage(
                            state: widget.state,
                            onCamera: openCamera,
                          ),
                        ),
                        _KeepAlivePage(
                          child: ProgressPage(state: widget.state),
                        ),
                        _KeepAlivePage(
                          child: SettingsPage(
                            state: widget.state,
                            cloud: widget.cloud,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: _FloatingTabBar(index: index, onChanged: select),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebDownloadLinks extends StatelessWidget {
  const _WebDownloadLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HairLine(),
        const SizedBox(height: 16),
        const Text(
          '手机版',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'iPhone：在 Safari 里点「分享」，再点「添加到主屏幕」，或下载 IPA 自签安装。\n'
          'Android：下载 APK 安装。网页版无需下载也能继续使用。',
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: AppColors.secondary,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DownloadButton(
                label: '下载 iOS 版',
                icon: Icons.apple,
                url: AppConfig.iosDownloadUrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DownloadButton(
                label: '下载 Android 版',
                icon: Icons.android,
                url: AppConfig.androidDownloadUrl,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => unawaited(openExternalLink(url)),
      haptic: true,
      scale: 0.97,
      opacity: 0.92,
      semanticLabel: label,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: AppColors.accentDeep),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentDeep,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TabBarItem {
  const _TabBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const items = <_TabBarItem>[
    _TabBarItem(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: '今天',
    ),
    _TabBarItem(
      icon: CupertinoIcons.square_list,
      selectedIcon: CupertinoIcons.square_list_fill,
      label: '记录',
    ),
    _TabBarItem(
      icon: CupertinoIcons.chart_bar,
      selectedIcon: CupertinoIcons.chart_bar_fill,
      label: '趋势',
    ),
    _TabBarItem(
      icon: CupertinoIcons.person,
      selectedIcon: CupertinoIcons.person_fill,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(420.0, math.max(296.0, screenWidth - 44));
    const height = 66.0;
    const inset = 6.0;
    final itemWidth = (width - inset * 2) / items.length;

    final content = Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            // 网页端没有背景模糊，改为不透明避免下层内容透出来发灰。
            color: kIsWeb ? const Color(0xFF000000) : const Color(0xE6000000),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          left: inset + itemWidth * index,
          top: inset,
          bottom: inset,
          width: itemWidth,
          child: const _SelectionPill(),
        ),
        Row(
          children: [
            for (var itemIndex = 0; itemIndex < items.length; itemIndex++)
              Expanded(
                child: _TabBarButton(
                  item: items[itemIndex],
                  selected: itemIndex == index,
                  onTap: () => onChanged(itemIndex),
                ),
              ),
          ],
        ),
      ],
    );

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: kIsWeb
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 36,
                    offset: Offset(0, 16),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: kIsWeb
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(999),
        boxShadow: kIsWeb
            ? null
            : const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
    );
  }
}

class _TabBarButton extends StatelessWidget {
  const _TabBarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _TabBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      opacity: 1,
      semanticLabel: item.label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1 : 0.94,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: Icon(
              selected ? item.selectedIcon : item.icon,
              size: 20,
              color: selected ? AppColors.ink : const Color(0x8CF5F5F7),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontFamily: 'MeicanSans',
              fontSize: 10.5,
              height: 1.1,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.1,
              color: selected ? AppColors.ink : const Color(0x73F5F5F7),
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
