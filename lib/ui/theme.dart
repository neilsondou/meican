import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const backgroundDeep = Color(0xFF000000);

  /// Near-white content color: text and icons on glass or on the canvas.
  static const surface = Color(0xFFF5F5F7);

  /// Glass fills. All are translucent so the canvas and its light show
  /// through them.
  static const glass = Color(0x0EFFFFFF);
  static const glassStrong = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x26FFFFFF);
  static const surfaceMuted = Color(0x14FFFFFF);
  static const glassBlack = Color(0xD9141416);

  static const ink = Color(0xFFF5F5F7);
  static const secondary = Color(0xA8F5F5F7);
  static const tertiary = Color(0x66F5F5F7);
  static const accent = Color(0xFFA8BFA8);
  static const accentDeep = Color(0xFFC2D6C1);
  static const accentSoft = Color(0x24A8BFA8);
  static const warm = Color(0xFFD9A77A);
  static const line = Color(0x1FFFFFFF);
  static const lineStrong = Color(0x33FFFFFF);
  static const warning = Color(0xFFE29379);
  static const danger = Color(0xFFFF453A);
  static const scrim = Color(0xB8000000);
}

abstract final class AppRadius {
  static const card = 28.0;
  static const sheet = 36.0;
  static const field = 18.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 18)),
  ];
  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 44, offset: Offset(0, 22)),
  ];
  static const thumb = <BoxShadow>[
    BoxShadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 5)),
  ];
}

abstract final class AppTextStyles {
  static const largeTitle = TextStyle(
    fontSize: 38,
    height: 1.04,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.3,
    color: AppColors.ink,
  );
  static const pageTitle = TextStyle(
    fontSize: 32,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    color: AppColors.ink,
  );
  static const sectionTitle = TextStyle(
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );
  static const headline = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );
  static const callout = TextStyle(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
  );
  static const footnote = TextStyle(
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.secondary,
  );
  static const eyebrow = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.accentDeep,
  );
  static const numericHero = TextStyle(
    fontSize: 68,
    height: 0.95,
    fontWeight: FontWeight.w600,
    letterSpacing: -3,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numericLarge = TextStyle(
    fontSize: 44,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.8,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numericCard = TextStyle(
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numericInline = TextStyle(
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

const SystemUiOverlayStyle appSystemOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarDividerColor: Colors.transparent,
);

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    secondary: AppColors.warm,
    onSecondary: AppColors.background,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    outline: AppColors.lineStrong,
    error: AppColors.warning,
    onError: AppColors.background,
  );

  const textTheme = TextTheme(
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
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: const Color(0x0AFFFFFF),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 0.7,
      space: 0.7,
    ),
    textTheme: textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    primaryTextTheme: textTheme,
    iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      hintStyle: const TextStyle(
        color: AppColors.tertiary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(color: AppColors.secondary, fontSize: 14),
      floatingLabelStyle: const TextStyle(
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
        borderSide: const BorderSide(color: AppColors.line, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.warning, width: 1),
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
        side: const BorderSide(color: AppColors.glassBorder, width: 1),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF141416),
      contentTextStyle: const TextStyle(
        color: AppColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF111113),
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
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.accentDeep,
      barBackgroundColor: Color(0xE60E0E10),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: CupertinoTextThemeData(
        navTitleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
        navLargeTitleTextStyle: AppTextStyles.largeTitle,
        textStyle: AppTextStyles.body,
        pickerTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        actionTextStyle: TextStyle(
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
