import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_state.dart';
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
  runApp(MeiCanApp(state: AppState()));
}

class MeiCanApp extends StatefulWidget {
  const MeiCanApp({super.key, required this.state});

  final AppState state;

  @override
  State<MeiCanApp> createState() => _MeiCanAppState();
}

class _MeiCanAppState extends State<MeiCanApp> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.state.load());
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
        child: child ?? const SizedBox.shrink(),
      ),
      home: _Root(state: widget.state),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root({required this.state});

  final AppState state;

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
          child: state.ready
              ? AppShell(key: const ValueKey('shell'), state: state)
              : const LaunchView(key: ValueKey('launch')),
        );
      },
    );
  }
}

class LaunchView extends StatelessWidget {
  const LaunchView({super.key});

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
                const Text(
                  '每餐',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 10,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '每一餐，都清清楚楚',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: AppColors.tertiary,
                  ),
                ),
                const SizedBox(height: 30),
                const SizedBox.square(
                  dimension: 22,
                  child: CupertinoActivityIndicator(
                    radius: 9,
                    color: AppColors.accent,
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
  const AppShell({super.key, required this.state});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  final Set<int> _visited = {0};

  void select(int value) {
    if (value == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      index = value;
      _visited.add(value);
    });
  }

  void openCamera() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AiCapturePage(state: widget.state),
      ),
    );
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
                    final pages = <Widget>[
                      HomePage(
                        state: widget.state,
                        onCamera: openCamera,
                        onOpenRecord: () => select(1),
                        onOpenProgress: () => select(2),
                      ),
                      RecordPage(state: widget.state, onCamera: openCamera),
                      ProgressPage(state: widget.state),
                      SettingsPage(state: widget.state),
                    ];
                    return _TabViewport(
                      index: index,
                      visited: _visited,
                      children: pages,
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

class _TabViewport extends StatefulWidget {
  const _TabViewport({
    required this.index,
    required this.visited,
    required this.children,
  });

  final int index;
  final Set<int> visited;
  final List<Widget> children;

  @override
  State<_TabViewport> createState() => _TabViewportState();
}

class _TabViewportState extends State<_TabViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.fastEaseInToSlowEaseOut,
  );
  late int _current = widget.index;
  int? _previous;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _previous != null && mounted) {
        setState(() => _previous = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TabViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previous = _current;
      _forward = widget.index > _current;
      _current = widget.index;
      _controller.stop();
      if (MediaQuery.disableAnimationsOf(context)) {
        _previous = null;
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _offsetFor(int page, double t) {
    if (_previous == null || t >= 1) return Offset.zero;
    final direction = _forward ? 1.0 : -1.0;
    if (page == _current) {
      return Offset(direction * 0.26 * (1 - t), 0);
    }
    if (page == _previous) {
      return Offset(-direction * 0.08 * t, 0);
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          final t = _curve.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              for (
                var pageIndex = 0;
                pageIndex < widget.children.length;
                pageIndex++
              )
                KeyedSubtree(
                  key: ValueKey('tab-$pageIndex'),
                  child: Offstage(
                    offstage: pageIndex != _current && pageIndex != _previous,
                    child: IgnorePointer(
                      ignoring: pageIndex != _current,
                      child: TickerMode(
                        enabled: pageIndex == _current,
                        child: FractionalTranslation(
                          translation: _offsetFor(pageIndex, t),
                          child: widget.visited.contains(pageIndex)
                              ? widget.children[pageIndex]
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
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

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xE6000000)),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height / 2),
                    border: Border.all(
                      color: const Color(0x1FFFFFFF),
                      width: 1,
                    ),
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
        boxShadow: const [
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
