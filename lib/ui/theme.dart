import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppPalette {
  const AppPalette({
    required this.isDark,
    required this.background,
    required this.backgroundDeep,
    required this.surface,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.surfaceMuted,
    required this.glassBlack,
    required this.ink,
    required this.secondary,
    required this.tertiary,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.warm,
    required this.cool,
    required this.line,
    required this.lineStrong,
    required this.warning,
    required this.danger,
    required this.scrim,
    required this.sheet,
    required this.dialog,
    required this.toast,
    required this.dock,
    required this.tabBar,
    required this.tabBarWeb,
    required this.tabPill,
    required this.pillThumb,
    required this.borderStrong,
    required this.ring,
    required this.dateSheet,
    required this.cupertinoBar,
    required this.fieldFill,
    required this.hover,
    required this.handle,
    required this.alertButton,
    required this.onSurfaceBorder,
    required this.barTop,
    required this.barBottom,
    required this.barMutedTop,
    required this.barMutedBottom,
  });

  final bool isDark;
  final Color background;
  final Color backgroundDeep;
  final Color surface;
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;
  final Color surfaceMuted;
  final Color glassBlack;
  final Color ink;
  final Color secondary;
  final Color tertiary;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color warm;
  final Color cool;
  final Color line;
  final Color lineStrong;
  final Color warning;
  final Color danger;
  final Color scrim;
  final Color sheet;
  final Color dialog;
  final Color toast;
  final Color dock;
  final Color tabBar;
  final Color tabBarWeb;
  final Color tabPill;
  final Color pillThumb;
  final Color borderStrong;
  final Color ring;
  final Color dateSheet;
  final Color cupertinoBar;
  final Color fieldFill;
  final Color hover;
  final Color handle;
  final Color alertButton;
  final Color onSurfaceBorder;
  final Color barTop;
  final Color barBottom;
  final Color barMutedTop;
  final Color barMutedBottom;
}

const AppPalette darkPalette = AppPalette(
  isDark: true,
  background: Color(0xFF000000),
  backgroundDeep: Color(0xFF000000),
  surface: Color(0xFFF5F5F7),
  glass: Color(0x0EFFFFFF),
  glassStrong: Color(0x1AFFFFFF),
  glassBorder: Color(0x26FFFFFF),
  surfaceMuted: Color(0x14FFFFFF),
  glassBlack: Color(0xD9141416),
  ink: Color(0xFFF5F5F7),
  secondary: Color(0xA8F5F5F7),
  tertiary: Color(0x66F5F5F7),
  accent: Color(0xFFA8BFA8),
  accentDeep: Color(0xFFC2D6C1),
  accentSoft: Color(0x24A8BFA8),
  warm: Color(0xFFD9A77A),
  cool: Color(0xFFA9B7C9),
  line: Color(0x1FFFFFFF),
  lineStrong: Color(0x33FFFFFF),
  warning: Color(0xFFE29379),
  danger: Color(0xFFFF453A),
  scrim: Color(0xB8000000),
  sheet: Color(0xF20C0C0D),
  dialog: Color(0xE61A1A1C),
  toast: Color(0xF0141416),
  dock: Color(0xF20A0A0B),
  tabBar: Color(0xE6000000),
  tabBarWeb: Color(0xFF000000),
  tabPill: Color(0xFF1C1C1E),
  pillThumb: Color(0xFF232326),
  borderStrong: Color(0x33FFFFFF),
  ring: Color(0x14FFFFFF),
  dateSheet: Color(0xFF161618),
  cupertinoBar: Color(0xE60E0E10),
  fieldFill: Color(0x14FFFFFF),
  hover: Color(0x0AFFFFFF),
  handle: Color(0x3DFFFFFF),
  alertButton: Color(0x26FFFFFF),
  onSurfaceBorder: Color(0x66FFFFFF),
  barTop: Color(0xFFD5E2D2),
  barBottom: Color(0xFFA8BFA8),
  barMutedTop: Color(0xFF93A593),
  barMutedBottom: Color(0xFF6E826F),
);

/// Warm off-white canvas with milk-white cards; all accents keep the same
/// hues as the dark theme so layouts and effects stay identical.
const AppPalette lightPalette = AppPalette(
  isDark: false,
  background: Color(0xFFF4EFE5),
  backgroundDeep: Color(0xFFF4EFE5),
  surface: Color(0xFF2C2820),
  glass: Color(0x0F5B4C37),
  glassStrong: Color(0x1A5B4C37),
  glassBorder: Color(0x245B4C37),
  surfaceMuted: Color(0x145B4C37),
  glassBlack: Color(0xF5FFFDF7),
  ink: Color(0xFF29251E),
  secondary: Color(0xA629251E),
  tertiary: Color(0x7329251E),
  accent: Color(0xFF728E71),
  accentDeep: Color(0xFF4D6B50),
  accentSoft: Color(0x1F557A58),
  warm: Color(0xFFA56F3E),
  cool: Color(0xFF5E7186),
  line: Color(0x1F4A3F2E),
  lineStrong: Color(0x334A3F2E),
  warning: Color(0xFFB2553D),
  danger: Color(0xFFC4332A),
  scrim: Color(0x66000000),
  sheet: Color(0xFFFCF8EF),
  dialog: Color(0xFFFDFAF3),
  toast: Color(0xFFFDFAF3),
  dock: Color(0xFFFBF7EE),
  tabBar: Color(0xE6FBF7EE),
  tabBarWeb: Color(0xFFFBF7EE),
  tabPill: Color(0xFFFFFFFF),
  pillThumb: Color(0xFFFFFFFF),
  borderStrong: Color(0x2E5B4C37),
  ring: Color(0x124A3F2E),
  dateSheet: Color(0xFFFBF7EE),
  cupertinoBar: Color(0xE6FBF7EE),
  fieldFill: Color(0x0F5B4C37),
  hover: Color(0x0A000000),
  handle: Color(0x335B4C37),
  alertButton: Color(0x145B4C37),
  onSurfaceBorder: Color(0x33FFFFFF),
  barTop: Color(0xFF8FA88F),
  barBottom: Color(0xFF728E71),
  barMutedTop: Color(0xFFA9BCA9),
  barMutedBottom: Color(0xFF849A85),
);

abstract final class AppColors {
  static AppPalette palette = darkPalette;

  static bool get isDark => palette.isDark;

  static Color get background => palette.background;
  static Color get backgroundDeep => palette.backgroundDeep;

  /// Solid control fill: near-white on the dark canvas, warm charcoal on the
  /// cream canvas. Text on it uses [background].
  static Color get surface => palette.surface;

  /// Glass fills. All are translucent so the canvas shows through them.
  static Color get glass => palette.glass;
  static Color get glassStrong => palette.glassStrong;
  static Color get glassBorder => palette.glassBorder;
  static Color get surfaceMuted => palette.surfaceMuted;
  static Color get glassBlack => palette.glassBlack;

  static Color get ink => palette.ink;
  static Color get secondary => palette.secondary;
  static Color get tertiary => palette.tertiary;
  static Color get accent => palette.accent;
  static Color get accentDeep => palette.accentDeep;
  static Color get accentSoft => palette.accentSoft;
  static Color get warm => palette.warm;
  static Color get cool => palette.cool;
  static Color get line => palette.line;
  static Color get lineStrong => palette.lineStrong;
  static Color get warning => palette.warning;
  static Color get danger => palette.danger;
  static Color get scrim => palette.scrim;

  static Color get sheet => palette.sheet;
  static Color get dialog => palette.dialog;
  static Color get toast => palette.toast;
  static Color get dock => palette.dock;
  static Color get tabBar => palette.tabBar;
  static Color get tabBarWeb => palette.tabBarWeb;
  static Color get tabPill => palette.tabPill;
  static Color get pillThumb => palette.pillThumb;
  static Color get borderStrong => palette.borderStrong;
  static Color get ring => palette.ring;
  static Color get dateSheet => palette.dateSheet;
  static Color get cupertinoBar => palette.cupertinoBar;
  static Color get fieldFill => palette.fieldFill;
  static Color get hover => palette.hover;
  static Color get handle => palette.handle;
  static Color get alertButton => palette.alertButton;
  static Color get onSurfaceBorder => palette.onSurfaceBorder;
  static Color get barTop => palette.barTop;
  static Color get barBottom => palette.barBottom;
  static Color get barMutedTop => palette.barMutedTop;
  static Color get barMutedBottom => palette.barMutedBottom;

  /// Fixed light text for labels that sit on top of photos.
  static const Color onImage = Color(0xFFF5F5F7);
}

abstract final class AppRadius {
  static const card = 28.0;
  static const sheet = 36.0;
  static const field = 18.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  static List<BoxShadow> get card => AppColors.isDark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1A6B5A3E),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ];

  static List<BoxShadow> get raised => AppColors.isDark
      ? const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 44,
            offset: Offset(0, 22),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x246B5A3E),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ];

  static List<BoxShadow> get thumb => AppColors.isDark
      ? const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ];
}

abstract final class AppTextStyles {
  static TextStyle get largeTitle => TextStyle(
    fontSize: 38,
    height: 1.04,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.3,
    color: AppColors.ink,
  );

  static TextStyle get pageTitle => TextStyle(
    fontSize: 32,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    color: AppColors.ink,
  );

  static TextStyle get sectionTitle => TextStyle(
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static TextStyle get headline => TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static TextStyle get body => TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static TextStyle get callout => TextStyle(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
  );

  static TextStyle get footnote => TextStyle(
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
  );

  static TextStyle get caption => TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.secondary,
  );

  static TextStyle get eyebrow => TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.accentDeep,
  );

  static TextStyle get numericHero => TextStyle(
    fontSize: 68,
    height: 0.95,
    fontWeight: FontWeight.w600,
    letterSpacing: -3,
    color: AppColors.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get numericLarge => TextStyle(
    fontSize: 44,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.8,
    color: AppColors.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get numericCard => TextStyle(
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
    color: AppColors.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get numericInline => TextStyle(
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

SystemUiOverlayStyle appOverlayFor(bool isDark) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

ThemeData buildAppTheme() {
  final dark = AppColors.isDark;
  final scheme = dark
      ? ColorScheme.dark(
          primary: AppColors.accent,
          onPrimary: AppColors.background,
          secondary: AppColors.warm,
          onSecondary: AppColors.background,
          surface: AppColors.background,
          onSurface: AppColors.ink,
          outline: AppColors.lineStrong,
          error: AppColors.warning,
          onError: AppColors.background,
        )
      : ColorScheme.light(
          primary: AppColors.accentDeep,
          onPrimary: AppColors.background,
          secondary: AppColors.warm,
          onSecondary: AppColors.background,
          surface: AppColors.background,
          onSurface: AppColors.ink,
          outline: AppColors.lineStrong,
          error: AppColors.warning,
          onError: AppColors.background,
        );

  final textTheme = TextTheme(
    displayLarge: AppTextStyles.largeTitle,
    displayMedium: AppTextStyles.pageTitle,
    headlineMedium: AppTextStyles.sectionTitle,
    headlineSmall: AppTextStyles.headline,
    titleLarge: AppTextStyles.headline,
    titleMedium: AppTextStyles.headline,
    bodyLarge: AppTextStyles.body,
    bodyMedium: AppTextStyles.callout,
    bodySmall: AppTextStyles.footnote,
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.background,
    ),
    labelMedium: AppTextStyles.caption,
    labelSmall: AppTextStyles.eyebrow,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'MeicanSans',
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: AppColors.hover,
    dividerColor: AppColors.line,
    dividerTheme: DividerThemeData(
      color: AppColors.line,
      thickness: 0.7,
      space: 0.7,
    ),
    textTheme: textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: AppColors.ink, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fieldFill,
      hintStyle: TextStyle(
        color: AppColors.tertiary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(color: AppColors.secondary, fontSize: 14),
      floatingLabelStyle: TextStyle(
        color: AppColors.accentDeep,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: AppColors.line, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: AppColors.accent, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: AppColors.warning, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 54),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.background,
        disabledBackgroundColor: AppColors.glassStrong,
        disabledForegroundColor: AppColors.tertiary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentDeep,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(44, 54),
        side: BorderSide(color: AppColors.glassBorder, width: 1),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.toast,
      contentTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.glassBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.dialog,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: AppTextStyles.headline,
      contentTextStyle: AppTextStyles.callout,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      elevation: 0,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      primaryColor: AppColors.accentDeep,
      barBackgroundColor: AppColors.cupertinoBar,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: CupertinoTextThemeData(
        navTitleTextStyle: TextStyle(
          fontFamily: 'MeicanSans',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
        navLargeTitleTextStyle: AppTextStyles.largeTitle.copyWith(
          fontFamily: 'MeicanSans',
        ),
        textStyle: AppTextStyles.body.copyWith(fontFamily: 'MeicanSans'),
        pickerTextStyle: TextStyle(
          fontFamily: 'MeicanSans',
          fontSize: 21,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        actionTextStyle: TextStyle(
          fontFamily: 'MeicanSans',
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: AppColors.accentDeep,
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

String formatNumber(double value) => value.roundToDouble() == value
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String formatCalories(double value) => value.round().toString();

String formatSignedCalories(double value) {
  final rounded = value.round();
  return rounded > 0 ? '+$rounded' : '$rounded';
}
