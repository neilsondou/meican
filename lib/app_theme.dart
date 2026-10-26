import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/theme.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const String _storageKey = 'meican_light_mode';

  bool _isDark = true;

  bool get isDark => _isDark;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _isDark = !(preferences.getBool(_storageKey) ?? false);
    } catch (_) {}
    AppColors.palette = _isDark ? darkPalette : lightPalette;
    SystemChrome.setSystemUIOverlayStyle(appOverlayFor(_isDark));
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    AppColors.palette = value ? darkPalette : lightPalette;
    SystemChrome.setSystemUIOverlayStyle(appOverlayFor(value));
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_storageKey, !value);
    } catch (_) {}
  }
}
